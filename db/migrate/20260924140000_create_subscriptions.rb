# Phase 1's only table (DEC-013, DEC-073). The three check constraints make
# DEC-034's normalization structural rather than conventional: the Open Data API
# is exact-match and case-sensitive, so a lowercase plate returns a
# legitimate-looking `[]` and reads Clean forever — the quietest false all-clear
# in the system (invariant 1). Patterns are fixed against the observed domain
# and the probes behind them are recorded in DEC-086.
class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string :phone, null: false
      t.string :plate, null: false
      t.string :state, null: false

      t.timestamps
    end

    # A phone may hold several plates and a plate several phones (PRD §3); the
    # plate is polled once per run regardless (DEC-076).
    add_index :subscriptions, %i[phone plate state], unique: true

    # E.164. Rejects a bare 10-digit number rather than guessing a country code:
    # a mistyped phone is a send to someone who never subscribed (invariant 2).
    add_check_constraint :subscriptions,
      "phone ~ '^\\+[1-9][0-9]{7,14}$'",
      name: "subscriptions_phone_e164"

    # 1–10 uppercase alphanumerics. Observed plate lengths run 1–10 with no
    # separators or lowercase in any well-formed row (DEC-086).
    add_check_constraint :subscriptions,
      "plate ~ '^[A-Z0-9]{1,10}$'",
      name: "subscriptions_plate_normalized"

    # Exactly two uppercase alphanumerics — the whole observed domain, including
    # the numeric sentinels `99` and `88` that rule out `^[A-Z]{2}$` (DEC-076).
    add_check_constraint :subscriptions,
      "state ~ '^[A-Z0-9]{2}$'",
      name: "subscriptions_state_normalized"
  end
end
