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

ActiveRecord::Schema[7.1].define(version: 2025_06_24_161047) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "arch_image_gens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url"
  end

  create_table "building_analyses", force: :cascade do |t|
    t.json "key_influences"
    t.json "key_characteristics"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "html_content"
    t.integer "user_id", null: false
    t.string "image_url"
    t.text "h3_contents"
    t.boolean "visible_in_library"
    t.string "address", default: "N/A"
    t.float "latitude"
    t.float "longitude"
    t.string "city"
    t.index ["user_id"], name: "index_building_analyses_on_user_id"
  end

  create_table "dog_ratings", force: :cascade do |t|
    t.string "image"
    t.string "caption"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

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

  create_table "places", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.decimal "latitude", precision: 10, scale: 8, null: false
    t.decimal "longitude", precision: 11, scale: 8, null: false
    t.integer "zoom_level", default: 12
    t.text "description"
    t.text "content"
    t.boolean "published", default: false
    t.boolean "featured", default: false
    t.string "meta_title"
    t.string "meta_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hero_image_url"
    t.string "hero_image_alt"
    t.string "representative_image_url"
    t.datetime "content_generated_at"
    t.string "image_source", default: "placeholder"
    t.index ["content_generated_at"], name: "index_places_on_content_generated_at"
    t.index ["featured"], name: "index_places_on_featured"
    t.index ["image_source"], name: "index_places_on_image_source"
    t.index ["name"], name: "index_places_on_name", unique: true
    t.index ["published"], name: "index_places_on_published"
    t.index ["slug"], name: "index_places_on_slug", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.decimal "price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "screenshot_analyses", force: :cascade do |t|
    t.text "extracted_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_screenshot_analyses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "handle"
    t.string "public_name"
    t.text "bio"
    t.string "profile_picture"
    t.boolean "publicly_visible"
    t.boolean "display_stats"
    t.string "provider"
    t.string "uid"
    t.string "stripe_customer_id"
    t.string "subscription_status"
    t.integer "credits", default: 3, null: false
    t.boolean "admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider"], name: "index_users_on_provider"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
    t.index ["uid"], name: "index_users_on_uid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "building_analyses", "users"
  add_foreign_key "screenshot_analyses", "users"
end
