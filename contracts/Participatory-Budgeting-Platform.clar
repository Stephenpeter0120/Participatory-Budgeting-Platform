(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_CLOSED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u105))
(define-constant ERR_ALREADY_EXECUTED (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_CANNOT_DELEGATE_TO_SELF (err u108))
(define-constant ERR_DELEGATE_NOT_REGISTERED (err u109))

(define-constant ERR_CATEGORY_NOT_FOUND (err u110))
(define-constant ERR_CATEGORY_BUDGET_EXCEEDED (err u111))
(define-constant ERR_INVALID_CATEGORY (err u112))

(define-data-var next-proposal-id uint u1)
(define-data-var total-budget uint u0)
(define-data-var voting-period uint u1008)

(define-constant ERR_AMENDMENT_LIMIT_EXCEEDED (err u113))

(define-data-var max-amendments uint u3)

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



(define-map delegations
  principal
  principal
)

(define-map delegate-power
  principal
  uint
)

(define-public (delegate-voting-power (delegate principal))
  (let
    (
      (delegator tx-sender)
      (delegator-power (default-to u0 (map-get? citizen-voting-power delegator)))
      (current-delegate-power (default-to u0 (map-get? delegate-power delegate)))
      (existing-delegation (map-get? delegations delegator))
    )
    (asserts! (> delegator-power u0) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq delegator delegate)) ERR_CANNOT_DELEGATE_TO_SELF)
    (asserts! (> (default-to u0 (map-get? citizen-voting-power delegate)) u0) ERR_DELEGATE_NOT_REGISTERED)
    
    (match existing-delegation
      old-delegate 
      (map-set delegate-power old-delegate 
        (- (default-to u0 (map-get? delegate-power old-delegate)) delegator-power))
      true
    )
    
    (map-set delegations delegator delegate)
    (map-set delegate-power delegate (+ current-delegate-power delegator-power))
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let
    (
      (delegator tx-sender)
      (delegator-power (default-to u0 (map-get? citizen-voting-power delegator)))
    )
    (match (map-get? delegations delegator)
      delegate
      (begin
        (map-delete delegations delegator)
        (map-set delegate-power delegate 
          (- (default-to u0 (map-get? delegate-power delegate)) delegator-power))
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
  )
)

(define-private (get-effective-voting-power (voter principal))
  (let
    (
      (base-power (default-to u0 (map-get? citizen-voting-power voter)))
      (delegated-power (default-to u0 (map-get? delegate-power voter)))
    )
    (+ base-power delegated-power)
  )
)

(define-read-only (get-delegation (delegator principal))
  (map-get? delegations delegator)
)

(define-read-only (get-delegated-power (delegate principal))
  (default-to u0 (map-get? delegate-power delegate))
)

(define-read-only (get-total-voting-power (voter principal))
  (get-effective-voting-power voter)
)

(define-map budget-categories
  (string-ascii 50)
  {
    total-budget: uint,
    allocated: uint,
    active: bool
  }
)

(define-map proposal-categories
  uint
  (string-ascii 50)
)

(define-public (create-budget-category (name (string-ascii 50)) (budget uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> budget u0) ERR_INVALID_AMOUNT)
    (map-set budget-categories name {
      total-budget: budget,
      allocated: u0,
      active: true
    })
    (ok true)
  )
)

(define-public (update-category-budget (name (string-ascii 50)) (new-budget uint))
  (let
    (
      (category (unwrap! (map-get? budget-categories name) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= new-budget (get allocated category)) ERR_INVALID_AMOUNT)
    (map-set budget-categories name (merge category { total-budget: new-budget }))
    (ok true)
  )
)

(define-public (submit-categorized-proposal 
  (title (string-ascii 100)) 
  (description (string-ascii 500)) 
  (amount uint)
  (category (string-ascii 50)))
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-block stacks-block-height)
      (category-info (unwrap! (map-get? budget-categories category) ERR_CATEGORY_NOT_FOUND))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (get active category-info) ERR_INVALID_CATEGORY)
    (asserts! (<= (+ amount (get allocated category-info)) (get total-budget category-info)) ERR_CATEGORY_BUDGET_EXCEEDED)
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
    (map-set proposal-categories proposal-id category)
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (execute-categorized-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (category-name (unwrap! (map-get? proposal-categories proposal-id) ERR_CATEGORY_NOT_FOUND))
      (category (unwrap! (map-get? budget-categories category-name) ERR_CATEGORY_NOT_FOUND))
      (current-budget (var-get total-budget))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
    (asserts! (>= current-budget (get amount proposal)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (<= (+ (get amount proposal) (get allocated category)) (get total-budget category)) ERR_CATEGORY_BUDGET_EXCEEDED)
    
    (var-set total-budget (- current-budget (get amount proposal)))
    (map-set budget-categories category-name 
      (merge category { allocated: (+ (get allocated category) (get amount proposal)) }))
    (map-set proposals proposal-id (merge proposal { executed: true, status: "executed" }))
    (ok true)
  )
)

(define-read-only (get-category-budget (name (string-ascii 50)))
  (map-get? budget-categories name)
)

(define-read-only (get-proposal-category (proposal-id uint))
  (map-get? proposal-categories proposal-id)
)

(define-read-only (get-category-remaining (name (string-ascii 50)))
  (match (map-get? budget-categories name)
    category (some (- (get total-budget category) (get allocated category)))
    none
  )
)


(define-map proposal-amendments
  uint
  {
    amendment-count: uint,
    last-amended-at: uint,
    original-title: (string-ascii 100),
    original-description: (string-ascii 500),
    original-amount: uint
  }
)

(define-public (amend-proposal 
  (proposal-id uint) 
  (new-title (string-ascii 100)) 
  (new-description (string-ascii 500)) 
  (new-amount uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (amendment-info (default-to 
        { amendment-count: u0, last-amended-at: u0, 
          original-title: (get title proposal), 
          original-description: (get description proposal), 
          original-amount: (get amount proposal) }
        (map-get? proposal-amendments proposal-id)))
      (current-block stacks-block-height)
      (voting-deadline (+ (get created-at proposal) (var-get voting-period)))
    )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (<= current-block voting-deadline) ERR_VOTING_CLOSED)
    (asserts! (> new-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (< (get amendment-count amendment-info) (var-get max-amendments)) ERR_AMENDMENT_LIMIT_EXCEEDED)
    
    (map-set proposals proposal-id
      (merge proposal {
        title: new-title,
        description: new-description,
        amount: new-amount,
        votes-for: u0,
        votes-against: u0
      }))
    
    (map-set proposal-amendments proposal-id
      (merge amendment-info {
        amendment-count: (+ (get amendment-count amendment-info) u1),
        last-amended-at: current-block
      }))
    
    (ok true)
  )
)

(define-public (set-max-amendments (limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set max-amendments limit)
    (ok true)
  )
)

(define-read-only (get-amendment-info (proposal-id uint))
  (map-get? proposal-amendments proposal-id)
)

(define-read-only (get-max-amendments)
  (var-get max-amendments)
)