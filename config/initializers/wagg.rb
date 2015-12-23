# Tell Wagg our user/password for parsing
Rails.application.config.to_prepare do
  Wagg.configure do |c|
    c.retrieval_credentials['username'] = Figaro.env.wagg_username
    c.retrieval_credentials['password'] = Figaro.env.wagg_password
  end
end
