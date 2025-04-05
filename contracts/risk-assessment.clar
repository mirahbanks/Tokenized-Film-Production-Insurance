;; Risk Assessment Contract
;; Evaluates potential issues that could affect filming

(define-data-var contract-owner principal tx-sender)

;; Risk categories: 1 = low, 2 = medium, 3 = high
(define-map risk-assessments
  { project-id: uint }
  {
    assessor: principal,
    overall-risk-score: uint,
    location-risk: uint,
    weather-risk: uint,
    cast-risk: uint,
    equipment-risk: uint,
    assessment-date: uint,
    notes: (string-utf8 500)
  }
)

;; List of authorized risk assessors
(define-map authorized-assessors principal bool)

;; Map of verified projects (simplified from cross-contract calls)
(define-map verified-projects uint bool)

;; Events
(define-public (create-risk-assessment
    (project-id uint)
    (location-risk uint)
    (weather-risk uint)
    (cast-risk uint)
    (equipment-risk uint)
    (notes (string-utf8 500))
    (timestamp uint))
  (let
    ((is-assessor (default-to false (map-get? authorized-assessors tx-sender)))
     (assessment-exists (is-some (map-get? risk-assessments { project-id: project-id })))
     (is-verified (default-to false (map-get? verified-projects project-id)))
     (overall-score (+ (+ location-risk weather-risk) (+ cast-risk equipment-risk))))

    (asserts! is-assessor (err u1)) ;; Not authorized assessor
    (asserts! (not assessment-exists) (err u2)) ;; Assessment already exists
    (asserts! is-verified (err u3)) ;; Project not verified
    (asserts! (and (>= location-risk u1) (<= location-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= weather-risk u1) (<= weather-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= cast-risk u1) (<= cast-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= equipment-risk u1) (<= equipment-risk u3)) (err u4)) ;; Invalid risk score

    (map-set risk-assessments
      { project-id: project-id }
      {
        assessor: tx-sender,
        overall-risk-score: overall-score,
        location-risk: location-risk,
        weather-risk: weather-risk,
        cast-risk: cast-risk,
        equipment-risk: equipment-risk,
        assessment-date: timestamp,
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (update-risk-assessment
    (project-id uint)
    (location-risk uint)
    (weather-risk uint)
    (cast-risk uint)
    (equipment-risk uint)
    (notes (string-utf8 500))
    (timestamp uint))
  (let
    ((is-assessor (default-to false (map-get? authorized-assessors tx-sender)))
     (assessment (unwrap! (map-get? risk-assessments { project-id: project-id }) (err u5))) ;; Assessment not found
     (overall-score (+ (+ location-risk weather-risk) (+ cast-risk equipment-risk))))

    (asserts! is-assessor (err u1)) ;; Not authorized assessor
    (asserts! (and (>= location-risk u1) (<= location-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= weather-risk u1) (<= weather-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= cast-risk u1) (<= cast-risk u3)) (err u4)) ;; Invalid risk score
    (asserts! (and (>= equipment-risk u1) (<= equipment-risk u3)) (err u4)) ;; Invalid risk score

    (map-set risk-assessments
      { project-id: project-id }
      (merge assessment {
        overall-risk-score: overall-score,
        location-risk: location-risk,
        weather-risk: weather-risk,
        cast-risk: cast-risk,
        equipment-risk: equipment-risk,
        assessment-date: timestamp,
        notes: notes
      })
    )
    (ok true)
  )
)

;; Admin functions
(define-public (add-assessor (assessor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u6)) ;; Not contract owner
    (map-set authorized-assessors assessor true)
    (ok true)
  )
)

(define-public (remove-assessor (assessor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u6)) ;; Not contract owner
    (map-delete authorized-assessors assessor)
    (ok true)
  )
)

;; For testing/demo purposes - in a real system this would be handled by cross-contract calls
(define-public (set-project-verified (project-id uint) (verified bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u6)) ;; Not contract owner
    (map-set verified-projects project-id verified)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u6)) ;; Not contract owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-risk-assessment (project-id uint))
  (map-get? risk-assessments { project-id: project-id })
)

(define-read-only (get-risk-category (project-id uint))
  (match (map-get? risk-assessments { project-id: project-id })
    assessment (let ((score (get overall-risk-score assessment)))
                 (if (<= score u6)
                     u1 ;; Low risk (4-6)
                     (if (<= score u9)
                         u2 ;; Medium risk (7-9)
                         u3))) ;; High risk (10-12)
    u0 ;; No assessment
  )
)

(define-read-only (is-assessor (address principal))
  (default-to false (map-get? authorized-assessors address))
)

