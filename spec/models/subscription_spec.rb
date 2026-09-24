require "rails_helper"

RSpec.describe Subscription do
  # The full `state` domain as the API reports it, pulled 2026-09-24 (DEC-086).
  # Table-driven so "the constraint accepts every state the data contains" is a
  # test rather than a claim — and so a future tightening fails loudly.
  let(:observed_states) do
    JSON.parse(
      Rails.root.join("spec/fixtures/open_data/state-domain-2026-09-24.json").read
    ).map { |row| row.fetch("state") }
  end

  def insert_raw(phone: "+12125550147", plate: "JPR7462", state: "NY")
    # Bypasses validations *and* callbacks, so the database is what is under
    # test. The constraints are the guard; the model validations only echo them.
    # `insert_all!`, not `insert_all` — the latter is ON CONFLICT DO NOTHING and
    # would swallow the unique-index violation this also has to prove.
    described_class.insert_all!(
      [ { phone: phone, plate: plate, state: state, created_at: Time.current, updated_at: Time.current } ]
    )
  end

  describe "normalization (DEC-034)" do
    it "uppercases the plate and strips spaces and dashes" do
      subscription = described_class.new(phone: "+12125550147", plate: " jpr-74 62 ", state: "NY")
      subscription.valid?
      expect(subscription.plate).to eq("JPR7462")
    end

    it "uppercases the state" do
      subscription = described_class.new(phone: "+12125550147", plate: "JPR7462", state: "ny")
      subscription.valid?
      expect(subscription.state).to eq("NY")
    end

    it "strips separators from the phone without inferring a country code" do
      subscription = described_class.new(phone: "+1 212-555-0147", plate: "JPR7462", state: "NY")
      subscription.valid?
      expect(subscription.phone).to eq("+12125550147")
    end

    it "enrolls a plate typed the way a person types it" do
      subscription = described_class.enroll(phone: "+1 212-555-0147", plate: "jpr 7462", state: "ny")
      expect(subscription).to have_attributes(phone: "+12125550147", plate: "JPR7462", state: "NY")
    end
  end

  describe "validation" do
    it "accepts the numeric state sentinel that rules out ^[A-Z]{2}$ (DEC-076)" do
      expect(build(:subscription, state: "99")).to be_valid
    end

    it "reads a state-domain fixture that is populated, so the next example cannot pass vacuously" do
      expect(observed_states.size).to eq(70)
    end

    it "accepts every state value the dataset contains" do
      rejected = observed_states.reject { |state| build(:subscription, state: state).valid? }
      expect(rejected).to be_empty
    end

    it "rejects a plate that normalization cannot rescue" do
      expect(build(:subscription, plate: "JPR.7462")).not_to be_valid
    end

    it "rejects a plate longer than the observed domain" do
      expect(build(:subscription, plate: "ABCDEFGHIJK")).not_to be_valid
    end

    it "rejects a state that is not two characters" do
      expect(build(:subscription, state: "NYC")).not_to be_valid
    end

    it "rejects a phone with no country code rather than guessing one" do
      expect(build(:subscription, phone: "2125550147")).not_to be_valid
    end

    it "rejects blank columns" do
      expect(described_class.new).not_to be_valid
    end
  end

  describe "uniqueness (DEC-076)" do
    before { create(:subscription, phone: "+12125550147", plate: "JPR7462", state: "NY") }

    it "rejects the same phone, plate and state twice" do
      expect(build(:subscription, phone: "+12125550147", plate: "JPR7462", state: "NY")).not_to be_valid
    end

    it "allows one phone to hold several plates" do
      expect(build(:subscription, phone: "+12125550147", plate: "GGD5149", state: "NY")).to be_valid
    end

    it "allows one plate to be held by several phones" do
      expect(build(:subscription, phone: "+12125550148", plate: "JPR7462", state: "NY")).to be_valid
    end

    it "is enforced by the database, not only the model" do
      expect { insert_raw }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "database check constraints" do
    it "rejects a lowercase plate — the quietest false all-clear (invariant 1)" do
      expect { insert_raw(plate: "jpr7462") }
        .to raise_error(ActiveRecord::StatementInvalid, /subscriptions_plate_normalized/)
    end

    it "rejects a plate carrying separators" do
      expect { insert_raw(plate: "JPR 7462") }
        .to raise_error(ActiveRecord::StatementInvalid, /subscriptions_plate_normalized/)
    end

    it "rejects a lowercase state" do
      expect { insert_raw(state: "ny") }
        .to raise_error(ActiveRecord::StatementInvalid, /subscriptions_state_normalized/)
    end

    it "rejects a state that is not two characters" do
      expect { insert_raw(state: "NYC") }
        .to raise_error(ActiveRecord::StatementInvalid, /subscriptions_state_normalized/)
    end

    it "rejects a phone that is not E.164 — invariant 2's last guard" do
      expect { insert_raw(phone: "2125550147") }
        .to raise_error(ActiveRecord::StatementInvalid, /subscriptions_phone_e164/)
    end

    it "accepts the numeric state sentinel" do
      expect { insert_raw(state: "99") }.to change(described_class, :count).by(1)
    end
  end

  describe ".enroll" do
    it "creates the row" do
      expect { described_class.enroll(phone: "+12125550147", plate: "JPR7462", state: "NY") }
        .to change(described_class, :count).by(1)
    end

    it "raises on a plate the constraints reject, so the console sees it" do
      expect { described_class.enroll(phone: "+12125550147", plate: "JPR.7462", state: "NY") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "sends nothing — the Welcome arrives with the sender (issue #6)" do
      described_class.enroll(phone: "+12125550147", plate: "JPR7462", state: "NY")
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end
end
