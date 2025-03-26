# Deployment Guide for Flash-AI

This document provides instructions for deploying the Flash-AI application to various hosting platforms.

## General Preparation

Before deploying to any platform:

1. Ensure your application is properly committed to Git
2. Make sure your `config/master.key` is secure and not committed to the repository
3. Test your application locally with `RAILS_ENV=production rails server`

## Deploying to Render

[Render](https://render.com) is a unified cloud platform to build and run your apps.

### Automatic Deployment

This repository includes a `render.yaml` file that configures the application for deployment on Render:

1. Create a new Render account if you don't have one
2. From your Render dashboard, click "New +" and select "Blueprint"
3. Connect your GitHub repository
4. Render will detect the `render.yaml` file and set up your application
5. You'll need to manually set the `RAILS_MASTER_KEY` environment variable to the contents of your `config/master.key` file

### Manual Deployment

1. Create a new Web Service in Render
2. Connect your repository
3. Use the following settings:
   - **Runtime**: Ruby
   - **Build Command**: `bundle install && bin/rails assets:precompile && bin/rails db:migrate`
   - **Start Command**: `bundle exec puma -C config/puma.rb`
4. Add the following environment variables:
   - `RAILS_MASTER_KEY`: (contents of your `config/master.key` file)
   - `RAILS_ENV`: production
   - `RAILS_SERVE_STATIC_FILES`: true
   - `RENDER`: true

## Deploying to Heroku

1. Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
2. Login to Heroku: `heroku login`
3. Create a new application: `heroku create flash-ai-app`
4. Add your master key: `heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)`
5. Deploy the application: `git push heroku main`
6. Run migrations: `heroku run rails db:migrate`

## Troubleshooting

If you encounter CSRF errors after deployment:

1. The application includes special handling for CSRF tokens across different environments
2. If you still have issues, check the server logs for "CSRF Origin Check" messages
3. Make sure your forms are being properly updated with the correct domain by the JavaScript in application.html.erb

## Database Considerations

- By default, this application uses SQLite, which works well for development but may not be suitable for all production environments
- To use PostgreSQL on Render, modify your `database.yml` file and add a PostgreSQL database in the Render dashboard
- For high-traffic applications, consider using a managed database service 