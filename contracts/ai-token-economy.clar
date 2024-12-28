;; AI-Assisted Token Economy Smart Contract
;; Version: 1.2
;; Description: A token-driven economy that adapts dynamically to user behavior and market trends.

;; Storage
(define-data-var contract-owner principal tx-sender)

(define-map user-data
    { user: principal }
    {
        stake-amount: uint,
        reward-tier: (string-ascii 20),
        last-activity-block: uint
    }
)

(define-map market-trends
    { trend-id: uint }
    {
        trend-description: (string-ascii 100),
        impact-factor: int,
        created-block: uint
    }
)

(define-data-var total-supply uint u1000000)
(define-data-var reward-pool uint u100000)
(define-data-var dynamic-multiplier uint u1)
(define-data-var next-trend-id uint u1)

;; Constants
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INACTIVE-USER (err u102))
(define-constant ERR-INVALID-MULTIPLIER (err u103))
(define-constant ERR-INVALID-IMPACT (err u104))
(define-constant ERR-EMPTY-DESCRIPTION (err u105))
(define-constant MAX-MULTIPLIER u100)
(define-constant MAX-IMPACT-FACTOR 1000)
(define-constant MIN-IMPACT-FACTOR (- 1000))
(define-constant REWARD-MULTIPLIER-BASE u10)

;; Public Functions

(define-public (stake-tokens (amount uint))
    (let
        ((current-data (default-to 
            { stake-amount: u0, reward-tier: "basic", last-activity-block: block-height }
            (map-get? user-data { user: tx-sender })
        )))
        (asserts! (>= (var-get total-supply) amount) ERR-INSUFFICIENT-BALANCE)

        ;; Update user data
        (map-set user-data
            { user: tx-sender }
            {
                stake-amount: (+ (get stake-amount current-data) amount),
                reward-tier: (get reward-tier current-data),
                last-activity-block: block-height
            }
        )

        ;; Update total supply
        (var-set total-supply (- (var-get total-supply) amount))

        (ok true)
    )
)

(define-public (unstake-tokens (amount uint))
    (let
        ((user-info (unwrap! (map-get? user-data { user: tx-sender }) ERR-INACTIVE-USER)))
        (asserts! (>= (get stake-amount user-info) amount) ERR-INSUFFICIENT-BALANCE)

        ;; Update user data
        (map-set user-data
            { user: tx-sender }
            (merge user-info { stake-amount: (- (get stake-amount user-info) amount) })
        )

        ;; Update total supply
        (var-set total-supply (+ (var-get total-supply) amount))

        (ok true)
    )
)

(define-public (claim-rewards)
    (let
        (
            (user-info (unwrap! (map-get? user-data { user: tx-sender }) ERR-INACTIVE-USER))
            (tier-multiplier (if (is-eq (get reward-tier user-info) "basic")
                                  u1
                                  (if (is-eq (get reward-tier user-info) "silver")
                                      u2
                                      (if (is-eq (get reward-tier user-info) "gold")
                                          u3
                                          u1))))
            (reward (* (get stake-amount user-info) REWARD-MULTIPLIER-BASE tier-multiplier (var-get dynamic-multiplier)))
        )
        (asserts! (>= (var-get reward-pool) reward) ERR-INSUFFICIENT-BALANCE)

        ;; Transfer reward
        (var-set reward-pool (- (var-get reward-pool) reward))

        ;; Update last activity block
        (map-set user-data
            { user: tx-sender }
            (merge user-info { last-activity-block: block-height })
        )

        (ok reward)
    )
)

(define-public (adjust-dynamic-multiplier (new-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        ;; Validate the new multiplier is within acceptable bounds
        (asserts! (<= new-multiplier MAX-MULTIPLIER) ERR-INVALID-MULTIPLIER)
        (asserts! (> new-multiplier u0) ERR-INVALID-MULTIPLIER)
        (var-set dynamic-multiplier new-multiplier)
        (ok true)
    )
)

(define-public (log-market-trend (trend-description (string-ascii 100)) (impact-factor int))
    (let
        (
            (trend-id (var-get next-trend-id))
        )
        ;; Validate trend description is not empty and impact factor is within bounds
        (asserts! (not (is-eq trend-description "")) ERR-EMPTY-DESCRIPTION)
        (asserts! (<= impact-factor MAX-IMPACT-FACTOR) ERR-INVALID-IMPACT)
        (asserts! (>= impact-factor MIN-IMPACT-FACTOR) ERR-INVALID-IMPACT)
        
        (map-set market-trends
            { trend-id: trend-id }
            {
                trend-description: trend-description,
                impact-factor: impact-factor,
                created-block: block-height
            }
        )
        ;; Increment the next trend ID
        (var-set next-trend-id (+ trend-id u1))
        (ok trend-id)
    )
)

;; Read-Only Functions

(define-read-only (get-user-info (user principal))
    (map-get? user-data { user: user })
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-read-only (get-dynamic-multiplier)
    (ok (var-get dynamic-multiplier))
)

(define-read-only (get-market-trends)
    (ok "Functionality for map iteration not supported directly.")
)

(define-read-only (calculate-reward (user principal))
    (let
        (
            (user-info (unwrap! (map-get? user-data { user: user }) ERR-INACTIVE-USER))
            (tier-multiplier (if (is-eq (get reward-tier user-info) "basic")
                                  u1
                                  (if (is-eq (get reward-tier user-info) "silver")
                                      u2
                                      (if (is-eq (get reward-tier user-info) "gold")
                                          u3
                                          u1))))
            (reward (* (get stake-amount user-info) REWARD-MULTIPLIER-BASE tier-multiplier (var-get dynamic-multiplier)))
        )
        (ok reward)
    )
)