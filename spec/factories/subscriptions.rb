FactoryBot.define do
  factory :subscription do
    sequence(:phone) { |n| format("+1212555%04d", n) }
    plate { "JPR7462" }
    state { "NY" }
  end
end
