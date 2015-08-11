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

ActiveRecord::Schema.define(version: 20150810220236) do

  create_table "authors", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "signup"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "authors", ["id"], name: "index_authors_on_id", unique: true, using: :btree

  create_table "categories", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "categories", ["id"], name: "index_categories_on_id", unique: true, using: :btree
  add_index "categories", ["name"], name: "index_categories_on_name", unique: true, using: :btree

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

  create_table "news", force: :cascade do |t|
    t.string   "title",                 limit: 255
    t.text     "description",           limit: 65535
    t.datetime "timestamp_creation"
    t.datetime "timestamp_publication"
    t.string   "url_internal",          limit: 255
    t.string   "url_external",          limit: 255
    t.integer  "karma",                 limit: 4
    t.integer  "votes_count_positive",  limit: 4
    t.integer  "votes_count_negative",  limit: 4
    t.integer  "votes_count_anonymous", limit: 4
    t.integer  "clicks",                limit: 4
    t.integer  "comments_count",        limit: 4
    t.integer  "poster_id",             limit: 4
    t.string   "category",              limit: 255
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "news", ["id"], name: "index_news_on_id", unique: true, using: :btree
  add_index "news", ["poster_id"], name: "index_news_on_poster_id", using: :btree

  create_table "news_comments", id: false, force: :cascade do |t|
    t.integer "news_id",    limit: 4, null: false
    t.integer "comment_id", limit: 4, null: false
    t.integer "position",   limit: 4
  end

  add_index "news_comments", ["comment_id"], name: "index_news_comments_on_comment_id", using: :btree
  add_index "news_comments", ["news_id"], name: "index_news_comments_on_news_id", using: :btree

  create_table "news_tags", id: false, force: :cascade do |t|
    t.integer "news_id", limit: 4, null: false
    t.integer "tag_id",  limit: 4, null: false
  end

  add_index "news_tags", ["news_id"], name: "index_news_tags_on_news_id", using: :btree
  add_index "news_tags", ["tag_id"], name: "index_news_tags_on_tag_id", using: :btree

  create_table "tags", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

  create_table "votes", force: :cascade do |t|
    t.float    "weight",       limit: 24
    t.datetime "timestamp"
    t.integer  "votable_id",   limit: 4
    t.string   "votable_type", limit: 255
    t.integer  "voter_id",     limit: 4
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "votes", ["votable_type", "votable_id"], name: "index_votes_on_votable_type_and_votable_id", using: :btree
  add_index "votes", ["voter_id"], name: "voter", using: :btree

  add_foreign_key "comments", "authors", column: "commenter_id", name: "commenter"
  add_foreign_key "news", "authors", column: "poster_id", name: "poster"
  add_foreign_key "votes", "authors", column: "voter_id", name: "voter"
end
