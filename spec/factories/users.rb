FactoryBot.define do
  factory :user do
    email_address { Faker::Internet.email }
    password { Faker::Internet.password }
    password_confirmation { password }
end