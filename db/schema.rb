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

ActiveRecord::Schema[7.1].define(version: 2023_11_19_230334) do
  create_table "feedbacks", force: :cascade do |t|
    t.integer "user_id"
    t.boolean "vote"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "comment"
  end

  create_table "gpt_interactions", force: :cascade do |t|
    t.datetime "submitted_at"
    t.integer "response_time"
    t.text "user_input"
    t.text "gpt_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
