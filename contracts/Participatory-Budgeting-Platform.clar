(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_CLOSED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u105))
(define-constant ERR_ALREADY_EXECUTED (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))

(define-data-var next-proposal-id uint u1)
(define-data-var total-budget uint u0)
(define-data-var voting-period uint u1008)

(define-map proposals
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),
    created-at: uint,
    executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, amount: uint }
)

(define-map citizen-voting-power
  principal
  uint
)

(define-public (set-budget (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (var-set total-budget amount)
    (ok true)
  )
)

(define-public (register-citizen (citizen principal) (voting-power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set citizen-voting-power citizen voting-power)
    (ok true)
  )
)

(define-public (submit-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint))
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-block stacks-block-height)
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get total-budget)) ERR_INSUFFICIENT_FUNDS)
    (map-set proposals proposal-id
      {
        title: title,
        description: description,
        amount: amount,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        created-at: current-block,
        executed: false
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (support bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter-power (default-to u0 (map-get? citizen-voting-power tx-sender)))
      (current-block stacks-block-height)
      (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
    )
    (asserts! (> voter-power u0) ERR_UNAUTHORIZED)
    (asserts! (<= current-block voting-deadline) ERR_VOTING_CLOSED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { vote: support, amount: voter-power })
    
    (if support
      (map-set proposals proposal-id
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-power) })
      )
      (map-set proposals proposal-id
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-power) })
      )
    )
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (current-block stacks-block-height)
      (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (approval-threshold (/ total-votes u2))
    )
    (asserts! (> current-block voting-deadline) ERR_VOTING_CLOSED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    
    (if (> (get votes-for proposal) approval-threshold)
      (map-set proposals proposal-id (merge proposal { status: "approved" }))
      (map-set proposals proposal-id (merge proposal { status: "rejected" }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (current-budget (var-get total-budget))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
    (asserts! (>= current-budget (get amount proposal)) ERR_INSUFFICIENT_FUNDS)
    
    (var-set total-budget (- current-budget (get amount proposal)))
    (map-set proposals proposal-id (merge proposal { executed: true, status: "executed" }))
    (ok true)
  )
)

(define-public (set-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period blocks)
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-citizen-voting-power (citizen principal))
  (default-to u0 (map-get? citizen-voting-power citizen))
)

(define-read-only (get-total-budget)
  (var-get total-budget)
)

(define-read-only (get-voting-period)
  (var-get voting-period)
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

(define-read-only (is-voting-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (let
      (
        (current-block stacks-block-height)
        (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
      )
      (and 
        (<= current-block voting-deadline)
        (is-eq (get status proposal) "active")
      )
    )
    false
  )
)

(define-read-only (get-proposal-results (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (some {
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal),
      total-votes: (+ (get votes-for proposal) (get votes-against proposal)),
      status: (get status proposal)
    })
    none
  )
)
