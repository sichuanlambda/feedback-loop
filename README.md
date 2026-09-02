# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Programmatic SEO content

City guides (`/places/:slug`) and style-in-city pages (`/styles/:style/in/:city`) carry AI-written
content stored in the database (`places.content` / `places.faq`, `style_city_pages`). Both page types
also render a data-driven fallback intro and FAQ when nothing has been generated yet. Style-in-city
pages with fewer than `StyleCityPage::MIN_BUILDINGS` (3) buildings are served `noindex`; empty ones 404.

Generate content on production:

```bash
heroku run rake "places:add_cities[Amsterdam,Houston,London]"   # create + publish + write guide/FAQ (gpt-4o)
heroku run rake places:generate_faqs                            # FAQ backfill for guides that already have content
heroku run rake "seo:style_city_pages[3]"                       # intro + FAQ for every pair with >= 3 buildings (gpt-4o-mini)
heroku run rake seo:style_city_status                           # coverage report
```

The sitemap is a committed file (`public/sitemap*.xml.gz`), and Heroku's filesystem is ephemeral, so after
generating content regenerate it on a one-off dyno and copy it back before deploying:

```bash
heroku run --no-tty 'rake sitemap:generate >/dev/null && base64 public/sitemap1.xml.gz' | base64 -d > public/sitemap1.xml.gz
heroku run --no-tty 'base64 public/sitemap.xml.gz' | base64 -d > public/sitemap.xml.gz
```

Then commit the two files and deploy.

