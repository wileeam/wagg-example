# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20151218030054) do

  create_table "affinities", id: false, force: :cascade do |t|
    t.integer  "minor_id",           limit: 4,              null: false
    t.integer  "major_id",           limit: 4,              null: false
    t.integer  "closeness",          limit: 4,  default: 0
    t.float    "weighted_closeness", limit: 24
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  add_index "affinities", ["major_id"], name: "index_affinities_on_major_id", using: :btree
  add_index "affinities", ["minor_id"], name: "index_affinities_on_minor_id", using: :btree

  create_table "authors", force: :cascade do |t|
    t.string   "name",       limit: 191
    t.datetime "signup"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "authors", ["id"], name: "index_authors_on_id", unique: true, using: :btree
  add_index "authors", ["name"], name: "index_authors_on_name", using: :btree

  create_table "categories", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "categories", ["id"], name: "index_categories_on_id", unique: true, using: :btree

  create_table "comments", force: :cascade do |t|
    t.datetime "timestamp_creation"
    t.datetime "timestamp_edition"
    t.text     "body",               limit: 65535
    t.integer  "vote_count",         limit: 4
    t.integer  "karma",              limit: 4
    t.integer  "commenter_id",       limit: 4
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "comments", ["commenter_id"], name: "index_comments_on_commenter_id", using: :btree
  add_index "comments", ["id"], name: "index_comments_on_id", unique: true, using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,     default: 0, null: false
    t.integer  "attempts",   limit: 4,     default: 0, null: false
    t.text     "handler",    limit: 65535,             null: false
    t.text     "last_error", limit: 65535
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree
  add_index "delayed_jobs", ["queue"], name: "delayed_jobs_queue", length: {"queue"=>191}, using: :btree

  create_table "news", force: :cascade do |t|
    t.text     "title",                 limit: 65535
    t.text     "description",           limit: 65535
    t.string   "category",              limit: 191
    t.string   "status",                limit: 191
    t.datetime "timestamp_creation"
    t.datetime "timestamp_publication"
    t.text     "url_internal",          limit: 65535
    t.text     "url_external",          limit: 65535
    t.integer  "karma",                 limit: 4
    t.integer  "votes_count_positive",  limit: 4
    t.integer  "votes_count_negative",  limit: 4
    t.integer  "votes_count_anonymous", limit: 4
    t.integer  "clicks",                limit: 4
    t.integer  "comments_count",        limit: 4
    t.integer  "poster_id",             limit: 4
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "news", ["id"], name: "index_news_on_id", unique: true, using: :btree
  add_index "news", ["poster_id"], name: "index_news_on_poster_id", using: :btree
  add_index "news", ["url_internal"], name: "index_news_on_url_internal", length: {"url_internal"=>191}, using: :btree

  create_table "news_comments", id: false, force: :cascade do |t|
    t.integer "news_id",    limit: 4, null: false
    t.integer "comment_id", limit: 4, null: false
    t.integer "news_index", limit: 4, null: false
  end

  create_table "news_tags", id: false, force: :cascade do |t|
    t.integer "news_id", limit: 4
    t.integer "tag_id",  limit: 4
  end

  add_index "news_tags", ["news_id"], name: "news", using: :btree
  add_index "news_tags", ["tag_id"], name: "tag", using: :btree

  create_table "tags", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true, length: {"name"=>191}, using: :btree

  create_table "votes", id: false, force: :cascade do |t|
    t.float    "weight",       limit: 24
    t.datetime "timestamp"
    t.integer  "rate",         limit: 4
    t.integer  "votable_id",   limit: 4,   null: false
    t.string   "votable_type", limit: 255, null: false
    t.integer  "voter_id",     limit: 4,   null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "votes", ["votable_id", "votable_type"], name: "index_votes_on_votable_id_and_votable_type", using: :btree
  add_index "votes", ["votable_id"], name: "index_votes_on_votable_id", using: :btree
  add_index "votes", ["voter_id", "votable_id", "votable_type"], name: "index_votes_on_voter_id_and_votable_id_and_votable_type", using: :btree
  add_index "votes", ["voter_id"], name: "index_votes_on_voter_id", using: :btree

  add_foreign_key "affinities", "authors", column: "major_id", name: "major"
  add_foreign_key "affinities", "authors", column: "minor_id", name: "minor"
  add_foreign_key "comments", "authors", column: "commenter_id", name: "commenter"
  add_foreign_key "news", "authors", column: "poster_id", name: "poster"
  add_foreign_key "news_tags", "news", name: "news"
  add_foreign_key "news_tags", "tags", name: "tag"
  add_foreign_key "votes", "authors", column: "voter_id", name: "voter"
end
