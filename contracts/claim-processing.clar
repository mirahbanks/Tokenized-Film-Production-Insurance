;; Claim Processing Contract
;; Handles documentation and payment for covered events

(define-data-var contract-owner principal tx-sender)

;; Claim status: 0 = submitted, 1 = under review, 2 = approved, 3 = rejected, 4 = paid
(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    amount: uint,
    incident-date: uint,
    description: (string-utf8 500),
    status: uint,
    reviewer: (optional principal),
    review-date: (optional uint),
    payment-date: (optional uint),
    evidence-hash: (buff 32)
  }
)

;; Claim counter
(define-data-var claim-counter uint u0)

;; List of authorized claim reviewers
(define-map authorized-reviewers principal bool)

;; Map of policies (simplified from cross-contract calls)
(define-map policies
  { policy-id: uint }
  {
    policyholder: principal,
    coverage-limit: uint,
    start-date: uint,
    end-date: uint,
    is-active: bool
  }
)

;; Events
(define-public (submit-claim
    (policy-id uint)
    (amount uint)
    (incident-date uint)
    (description (string-utf8 500))
    (evidence-hash (buff 32))
    (timestamp uint))
  (let
    ((policy (unwrap! (map-get? policies { policy-id: policy-id }) (err u1))) ;; Policy not found
     (claim-id (+ (var-get claim-counter) u1)))

    (asserts! (is-eq tx-sender (get policyholder policy)) (err u2)) ;; Not policyholder
    (asserts! (get is-active policy) (err u3)) ;; Policy not active
    (asserts! (<= amount (get coverage-limit policy)) (err u4)) ;; Claim amount exceeds coverage limit
    (asserts! (and (>= incident-date (get start-date policy)) (<= incident-date (get end-date policy))) (err u5)) ;; Incident date outside policy period

    (var-set claim-counter claim-id)
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        amount: amount,
        incident-date: incident-date,
        description: description,
        status: u0, ;; submitted
        reviewer: none,
        review-date: none,
        payment-date: none,
        evidence-hash: evidence-hash
      }
    )
    (ok claim-id)
  )
)

(define-public (review-claim (claim-id uint) (new-status uint) (timestamp uint))
  (let
    ((claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u6))) ;; Claim not found
     (is-reviewer (default-to false (map-get? authorized-reviewers tx-sender))))

    (asserts! is-reviewer (err u7)) ;; Not authorized reviewer
    (asserts! (is-eq (get status claim) u0) (err u8)) ;; Claim not in submitted status
    (asserts! (or (is-eq new-status u1) (is-eq new-status u2) (is-eq new-status u3)) (err u9)) ;; Invalid status

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: new-status,
        reviewer: (some tx-sender),
        review-date: (some timestamp)
      })
    )
    (ok true)
  )
)

(define-public (process-payment (claim-id uint) (timestamp uint))
  (let
    ((claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u6))) ;; Claim not found
     (is-reviewer (default-to false (map-get? authorized-reviewers tx-sender))))

    (asserts! is-reviewer (err u7)) ;; Not authorized reviewer
    (asserts! (is-eq (get status claim) u2) (err u10)) ;; Claim not approved

    ;; In a real implementation, this would trigger a payment
    ;; For this example, we just update the status
    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: u4, ;; paid
        payment-date: (some timestamp)
      })
    )
    (ok true)
  )
)

;; For testing/demo purposes - in a real system this would be handled by cross-contract calls
(define-public (register-policy (policy-id uint) (policyholder principal) (coverage-limit uint) (start-date uint) (end-date uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u11)) ;; Not contract owner
    (map-set policies
      { policy-id: policy-id }
      {
        policyholder: policyholder,
        coverage-limit: coverage-limit,
        start-date: start-date,
        end-date: end-date,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Admin functions
(define-public (add-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u11)) ;; Not contract owner
    (map-set authorized-reviewers reviewer true)
    (ok true)
  )
)

(define-public (remove-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u11)) ;; Not contract owner
    (map-delete authorized-reviewers reviewer)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u11)) ;; Not contract owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-claim-count)
  (var-get claim-counter)
)

(define-read-only (is-reviewer (address principal))
  (default-to false (map-get? authorized-reviewers address))
)

