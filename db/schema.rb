# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_24_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "phone", null: false
    t.string "plate", null: false
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.index ["phone", "plate", "state"], name: "index_subscriptions_on_phone_and_plate_and_state", unique: true
    t.check_constraint "phone::text ~ '^\\+[1-9][0-9]{7,14}$'::text", name: "subscriptions_phone_e164"
    t.check_constraint "plate::text ~ '^[A-Z0-9]{1,10}$'::text", name: "subscriptions_plate_normalized"
    t.check_constraint "state::text ~ '^[A-Z0-9]{2}$'::text", name: "subscriptions_state_normalized"
  end
end
