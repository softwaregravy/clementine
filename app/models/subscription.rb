# One enrolled phone watching one plate. Phase 1's only table (DEC-013, DEC-073):
# no nickname, no `active` flag — console removal is `destroy`, and STOP is
# Twilio's, surfacing as error 21610 on the next send (DEC-075, DEC-076).
class Subscription < ApplicationRecord
  # Mirrors of the database check constraints, so the console gets a readable
  # error instead of a StatementInvalid. The database is the guard; these are the
  # manners. Keep the pairs in step — see DEC-086 for the observed domain.
  PHONE_FORMAT = /\A\+[1-9][0-9]{7,14}\z/
  PLATE_FORMAT = /\A[A-Z0-9]{1,10}\z/
  STATE_FORMAT = /\A[A-Z0-9]{2}\z/

  # DEC-034: uppercase, no spaces or dashes. A hard requirement, not a
  # convention — the API matches exactly and case-sensitively, so a lowercase
  # plate returns a legitimate-looking `[]` and reads Clean forever.
  SEPARATORS = /[\s-]/

  before_validation :normalize

  validates :phone, presence: true, format: { with: PHONE_FORMAT }
  validates :plate, presence: true, format: { with: PLATE_FORMAT }
  validates :state, presence: true, format: { with: STATE_FORMAT }
  validates :plate, uniqueness: { scope: %i[phone state] }

  # The console is the whole admin surface in Phase 1 (DEC-017). Creates the row
  # and sends nothing; the Welcome hangs here once the sender exists (issue #6).
  def self.enroll(phone:, plate:, state:)
    create!(phone: phone, plate: plate, state: state)
  end

  private

  def normalize
    self.phone = phone.to_s.gsub(SEPARATORS, "").presence
    self.plate = plate.to_s.gsub(SEPARATORS, "").upcase.presence
    self.state = state.to_s.gsub(SEPARATORS, "").upcase.presence
  end
end
