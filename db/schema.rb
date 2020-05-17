# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_05_17_163055) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "balancer_pools", force: :cascade do |t|
    t.bigint "pie_id"
    t.string "uma_address", limit: 42
    t.string "bp_address", limit: 42
    t.text "allocation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "swaps_completed", default: false, null: false
    t.index ["pie_id"], name: "index_balancer_pools_on_pie_id"
  end

  create_table "coin_infos", id: false, force: :cascade do |t|
    t.string "coin", limit: 8, null: false
    t.string "address", limit: 42, null: false
    t.integer "decimals", default: 18, null: false
    t.boolean "used", default: false, null: false
    t.text "abi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coin"], name: "index_coin_infos_on_coin", unique: true
  end

  create_table "cryptos", force: :cascade do |t|
    t.bigint "pie_id"
    t.integer "pct_curr1"
    t.integer "pct_curr2"
    t.integer "pct_curr3"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pie_id"], name: "index_cryptos_on_pie_id"
  end

  create_table "etfs", force: :cascade do |t|
    t.bigint "cca_id", null: false
    t.date "run_date", null: false
    t.string "ticker", limit: 32, null: false
    t.string "fund_name", limit: 128, null: false
    t.decimal "forecast_e", precision: 8, scale: 4
    t.decimal "forecast_s", precision: 8, scale: 4
    t.decimal "forecast_g", precision: 8, scale: 4
    t.decimal "esg_performance", precision: 8, scale: 4
    t.decimal "alpha", precision: 10, scale: 6
    t.decimal "price", precision: 10, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "m1_return"
    t.decimal "m3_return"
    t.decimal "m6_return"
    t.decimal "y1_return"
    t.index ["cca_id", "run_date"], name: "index_etfs_on_cca_id_and_run_date", unique: true
  end

  create_table "etfs_pies", id: false, force: :cascade do |t|
    t.bigint "pie_id"
    t.bigint "etf_id"
    t.index ["etf_id"], name: "index_etfs_pies_on_etf_id"
    t.index ["pie_id"], name: "index_etfs_pies_on_pie_id"
  end

  create_table "pies", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "pct_gold"
    t.integer "pct_crypto"
    t.integer "pct_cash"
    t.integer "pct_equities"
    t.string "name", limit: 32
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "performance"
    t.string "uma_collateral", limit: 8
    t.string "uma_token_name", limit: 32
    t.string "uma_expiry_date", limit: 16
    t.text "uma_snapshot"
    t.index ["user_id"], name: "index_pies_on_user_id"
  end

  create_table "pies_stocks", id: false, force: :cascade do |t|
    t.bigint "pie_id"
    t.bigint "stock_id"
    t.index ["pie_id"], name: "index_pies_stocks_on_pie_id"
    t.index ["stock_id"], name: "index_pies_stocks_on_stock_id"
  end

  create_table "price_histories", force: :cascade do |t|
    t.string "coin", limit: 8, null: false
    t.date "date", null: false
    t.decimal "price", precision: 8, scale: 2
    t.decimal "pct_change", precision: 12, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coin", "date"], name: "index_price_histories_on_coin_and_date", unique: true
  end

  create_table "price_identifiers", force: :cascade do |t|
    t.bigint "pie_id"
    t.string "whitelisted", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pie_id"], name: "index_price_identifiers_on_pie_id"
  end

  create_table "settings", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "e_priority", null: false
    t.integer "s_priority", null: false
    t.integer "g_priority", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "focus", limit: 32
    t.string "stable_coins"
    t.index ["user_id"], name: "index_settings_on_user_id"
  end

  create_table "stable_coins", force: :cascade do |t|
    t.bigint "pie_id"
    t.integer "pct_curr1"
    t.integer "pct_curr2"
    t.integer "pct_curr3"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pie_id"], name: "index_stable_coins_on_pie_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.bigint "cca_id", null: false
    t.date "run_date", null: false
    t.string "company_name", limit: 128, null: false
    t.string "sector", limit: 64, null: false
    t.decimal "forecast_e", precision: 8, scale: 4
    t.decimal "forecast_s", precision: 8, scale: 4
    t.decimal "forecast_g", precision: 8, scale: 4
    t.decimal "alpha", precision: 8, scale: 4
    t.float "m1_return"
    t.float "m3_return"
    t.float "m6_return"
    t.float "y1_return"
    t.decimal "price", precision: 10, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cca_id", "run_date"], name: "index_stocks_on_cca_id_and_run_date", unique: true
  end

  create_table "uma_expiry_dates", force: :cascade do |t|
    t.string "date_str", limit: 16, null: false
    t.string "unix", limit: 16, null: false
    t.integer "ordinal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
