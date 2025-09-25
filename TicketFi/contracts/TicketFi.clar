;; Gaming Arcade Contract
;; Operate arcade machines and earn ticket tokens
(define-fungible-token arcade-ticket)
(define-constant ARCADE-OWNER tx-sender)

;; Error Codes
(define-constant ERR-NOT-OWNER (err u101))
(define-constant ERR-INSUFFICIENT-TOKENS (err u102))
(define-constant ERR-NO-MACHINE-ACCESS (err u103))
(define-constant ERR-MACHINE-BROKEN (err u104))
(define-constant ERR-INVALID-MACHINE (err u105))
(define-constant ERR-INVALID-DIFFICULTY (err u106))
(define-constant ERR-INVALID-MULTIPLIER (err u107))
(define-constant ERR-INVALID-GAME-TYPE (err u108))

;; Constants for validation
(define-constant MAX-DIFFICULTY u10)
(define-constant MIN-DIFFICULTY u1)
(define-constant MAX-MULTIPLIER u200)
(define-constant MIN-MULTIPLIER u50)
(define-constant MAX-GAME-TYPE-LENGTH u28)

;; Arcade Variables
(define-data-var power-outage bool false)
(define-data-var outage-refund-rate uint u8) ;; 8% kept as maintenance fee during outage
(define-data-var tickets-per-play uint u4)
(define-data-var total-machine-tokens uint u0)
(define-data-var arcade-sections uint u0)

;; Data Maps
(define-map arcade-machines
  { machine-id: uint }
  { game-type: (string-ascii 28), difficulty: uint, ticket-multiplier: uint, total-tokens: uint, working: bool }
)

(define-map player-tokens
  { player: principal, machine-id: uint }
  { tokens-inserted: uint, last-play-block: uint }
)

;; Validation functions
(define-private (is-valid-difficulty (difficulty uint))
  (and (>= difficulty MIN-DIFFICULTY) (<= difficulty MAX-DIFFICULTY))
)

(define-private (is-valid-multiplier (multiplier uint))
  (and (>= multiplier MIN-MULTIPLIER) (<= multiplier MAX-MULTIPLIER))
)

(define-private (is-valid-game-type (game-type (string-ascii 28)))
  (and (> (len game-type) u0) (<= (len game-type) MAX-GAME-TYPE-LENGTH))
)

(define-private (is-valid-machine-id (machine-id uint))
  (< machine-id (var-get arcade-sections))
)

;; Setup arcade
(define-public (setup-arcade)
  (begin
    (try! (ft-mint? arcade-ticket u800000 ARCADE-OWNER))
    (try! (install-machine "Retro Games" u3 u75))
    (try! (install-machine "VR Station" u6 u110))
    (try! (install-machine "Tournament Arena" u9 u150))
    (ok true)
  )
)

;; Install arcade machine
(define-public (install-machine (game-type (string-ascii 28)) (difficulty uint) (multiplier uint))
  (begin
    (asserts! (is-eq tx-sender ARCADE-OWNER) ERR-NOT-OWNER)
    (asserts! (is-valid-game-type game-type) ERR-INVALID-GAME-TYPE)
    (asserts! (is-valid-difficulty difficulty) ERR-INVALID-DIFFICULTY)
    (asserts! (is-valid-multiplier multiplier) ERR-INVALID-MULTIPLIER)
    (let ((new-machine-id (var-get arcade-sections)))
      (map-set arcade-machines { machine-id: new-machine-id }
        { game-type: game-type, difficulty: difficulty, ticket-multiplier: multiplier, total-tokens: u0, working: true })
      (var-set arcade-sections (+ new-machine-id u1))
      (ok new-machine-id)
    )
  )
)

;; Insert tokens into machine
(define-public (insert-tokens (machine-id uint) (token-count uint))
  (begin
    (asserts! (> token-count u0) ERR-INSUFFICIENT-TOKENS)
    (asserts! (is-valid-machine-id machine-id) ERR-INVALID-MACHINE)
    (let ((machine (unwrap! (map-get? arcade-machines { machine-id: machine-id }) ERR-INVALID-MACHINE)))
      (asserts! (get working machine) ERR-MACHINE-BROKEN)
      (try! (ft-transfer? arcade-ticket token-count tx-sender (as-contract tx-sender)))
      (let ((current-play (default-to { tokens-inserted: u0, last-play-block: stacks-block-height }
              (map-get? player-tokens { player: tx-sender, machine-id: machine-id }))))
        (if (> (get tokens-inserted current-play) u0)
          (try! (award-tickets tx-sender (calculate-ticket-winnings tx-sender machine-id)))
          true)
        (map-set player-tokens { player: tx-sender, machine-id: machine-id }
          { tokens-inserted: (+ (get tokens-inserted current-play) token-count),
            last-play-block: stacks-block-height })
        (map-set arcade-machines { machine-id: machine-id }
          (merge machine { total-tokens: (+ (get total-tokens machine) token-count) }))
        (var-set total-machine-tokens (+ (var-get total-machine-tokens) token-count))
        (ok true)
      )
    )
  )
)

;; Cash out tokens from machine
(define-public (cash-out-tokens (machine-id uint) (token-count uint))
  (begin
    (asserts! (is-valid-machine-id machine-id) ERR-INVALID-MACHINE)
    (let ((play-session (unwrap! (map-get? player-tokens { player: tx-sender, machine-id: machine-id }) ERR-NO-MACHINE-ACCESS))
          (machine (unwrap! (map-get? arcade-machines { machine-id: machine-id }) ERR-INVALID-MACHINE)))
      (asserts! (<= token-count (get tokens-inserted play-session)) ERR-INSUFFICIENT-TOKENS)
      (try! (award-tickets tx-sender (calculate-ticket-winnings tx-sender machine-id)))
      (try! (as-contract (ft-transfer? arcade-ticket token-count tx-sender tx-sender)))
      (map-set player-tokens { player: tx-sender, machine-id: machine-id }
        { tokens-inserted: (- (get tokens-inserted play-session) token-count),
          last-play-block: stacks-block-height })
      (ok true)
    )
  )
)

;; Emergency power outage refund
(define-public (power-outage-refund (machine-id uint))
  (begin
    (asserts! (var-get power-outage) ERR-NOT-OWNER)
    (asserts! (is-valid-machine-id machine-id) ERR-INVALID-MACHINE)
    (let ((play-session (unwrap! (map-get? player-tokens { player: tx-sender, machine-id: machine-id }) ERR-NO-MACHINE-ACCESS))
          (tokens (get tokens-inserted play-session))
          (maintenance-fee (/ (* tokens (var-get outage-refund-rate)) u100)))
      (try! (as-contract (ft-transfer? arcade-ticket (- tokens maintenance-fee) tx-sender tx-sender)))
      (map-delete player-tokens { player: tx-sender, machine-id: machine-id })
      (ok (- tokens maintenance-fee))
    )
  )
)

;; Calculate ticket winnings
(define-private (calculate-ticket-winnings (player principal) (machine-id uint))
  (let ((play-session (unwrap! (map-get? player-tokens { player: player, machine-id: machine-id }) u0))
        (machine (unwrap! (map-get? arcade-machines { machine-id: machine-id }) u0))
        (games-played (- stacks-block-height (get last-play-block play-session))))
    (/ (* (get tokens-inserted play-session) games-played (var-get tickets-per-play) (get ticket-multiplier machine))
       (* (get total-tokens machine) u100))
  )
)

(define-private (award-tickets (player principal) (ticket-amount uint))
  (ft-mint? arcade-ticket ticket-amount player)
)

;; Admin functions
(define-public (trigger-power-outage (outage-active bool))
  (begin
    (asserts! (is-eq tx-sender ARCADE-OWNER) ERR-NOT-OWNER)
    (var-set power-outage outage-active)
    (ok outage-active)
  )
)

;; Read-only functions
(define-read-only (get-player-session (player principal) (machine-id uint))
  (default-to { tokens-inserted: u0, last-play-block: u0 }
    (map-get? player-tokens { player: player, machine-id: machine-id }))
)

(define-read-only (get-machine-info (machine-id uint))
  (map-get? arcade-machines { machine-id: machine-id })
)

(define-read-only (get-arcade-status)
  { total-machine-tokens: (var-get total-machine-tokens),
    power-outage: (var-get power-outage),
    arcade-sections: (var-get arcade-sections) })