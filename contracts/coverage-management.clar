;; Coverage Management Contract
;; Tracks specific insured aspects of production

(define-data-var contract-owner principal tx-sender)

;; Coverage types: 1 = cast, 2 = equipment, 3 = location, 4 = weather, 5 = comprehensive
(define-map coverages
  { policy-id: uint }
  {
    project-id: uint,
    policyholder: principal,
    coverage-type: uint,
    coverage-limit: uint,
    premium: uint,
    start-date: uint,
    end-date: uint,
    is-active: bool,
    creation-date: uint
  }
)

;; Policy counter
(define-data-var policy-counter uint u0)

;; Map of verified projects (simplified from cross-contract calls)
(define-map verified-projects uint bool)

;; Map of project risk categories (simplified from cross-contract calls)
(define-map project-risk-categories uint uint)

;; Map of project owners (simplified from cross-contract calls)
(define-map project-owners { project-id: uint } { owner: principal })

;; Events
(define-public (create-coverage
    (project-id uint)
    (coverage-type uint)
    (coverage-limit uint)
    (start-date uint)
    (end-date uint)
    (timestamp uint))
  (let
    ((is-verified (default-to false (map-get? verified-projects project-id)))
     (risk-category (default-to u0 (map-get? project-risk-categories project-id)))
     (project-owner-data (map-get? project-owners { project-id: project-id }))
     (policy-id (+ (var-get policy-counter) u1))
     (premium (calculate-premium coverage-limit risk-category coverage-type)))

    (asserts! is-verified (err u2)) ;; Project not verified
    (asserts! (> risk-category u0) (err u3)) ;; No risk assessment
    (asserts! (and (>= coverage-type u1) (<= coverage-type u5)) (err u4)) ;; Invalid coverage type
    (asserts! (> coverage-limit u0) (err u5)) ;; Coverage limit must be greater than 0
    (asserts! (>= start-date timestamp) (err u6)) ;; Start date must be in the future
    (asserts! (> end-date start-date) (err u7)) ;; End date must be after start date
    (asserts! (match project-owner-data
                owner-data (is-eq tx-sender (get owner owner-data))
                false)
              (err u8)) ;; Only project owner can create coverage

    (var-set policy-counter policy-id)
    (map-set coverages
      { policy-id: policy-id }
      {
        project-id: project-id,
        policyholder: tx-sender,
        coverage-type: coverage-type,
        coverage-limit: coverage-limit,
        premium: premium,
        start-date: start-date,
        end-date: end-date,
        is-active: true,
        creation-date: timestamp
      }
    )
    (ok policy-id)
  )
)

(define-public (cancel-coverage (policy-id uint))
  (let
    ((policy (unwrap! (map-get? coverages { policy-id: policy-id }) (err u9)))) ;; Policy not found

    (asserts! (is-eq tx-sender (get policyholder policy)) (err u10)) ;; Not policyholder
    (asserts! (get is-active policy) (err u11)) ;; Policy already inactive

    (map-set coverages
      { policy-id: policy-id }
      (merge policy { is-active: false })
    )
    (ok true)
  )
)

;; For testing/demo purposes - in a real system this would be handled by cross-contract calls
(define-public (set-project-verified (project-id uint) (verified bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u12)) ;; Not contract owner
    (map-set verified-projects project-id verified)
    (ok true)
  )
)

(define-public (set-project-risk-category (project-id uint) (risk-category uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u12)) ;; Not contract owner
    (asserts! (and (>= risk-category u1) (<= risk-category u3)) (err u13)) ;; Invalid risk category
    (map-set project-risk-categories project-id risk-category)
    (ok true)
  )
)

(define-public (set-project-owner (project-id uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u12)) ;; Not contract owner
    (map-set project-owners { project-id: project-id } { owner: owner })
    (ok true)
  )
)

;; Helper function to calculate premium based on risk and coverage
(define-private (calculate-premium (coverage-limit uint) (risk-category uint) (coverage-type uint))
  (let
    ((base-rate (if (is-eq coverage-type u1)
                    u5 ;; Cast: 5%
                    (if (is-eq coverage-type u2)
                        u3 ;; Equipment: 3%
                        (if (is-eq coverage-type u3)
                            u4 ;; Location: 4%
                            (if (is-eq coverage-type u4)
                                u6 ;; Weather: 6%
                                u8))))) ;; Comprehensive: 8%
     (risk-multiplier (if (is-eq risk-category u1)
                          u10 ;; Low risk: 1.0x
                          (if (is-eq risk-category u2)
                              u15 ;; Medium risk: 1.5x
                              u25)))) ;; High risk: 2.5x

    ;; Premium = (coverage-limit * base-rate * risk-multiplier) / 1000
    ;; Division by 1000 because we're using percentages multiplied by 10
    (/ (* (* coverage-limit base-rate) risk-multiplier) u1000)
  )
)

;; Read-only functions
(define-read-only (get-coverage (policy-id uint))
  (map-get? coverages { policy-id: policy-id })
)

(define-read-only (get-policy-count)
  (var-get policy-counter)
)

