# Single source of truth for subscription pricing shown in the app.
# Prices/links are overridable via Heroku config vars so pricing can change
# without a deploy: PLAN_MONTHLY_PRICE, STRIPE_MONTHLY_LINK, etc.
PLANS = {
  monthly: {
    price: ENV.fetch('PLAN_MONTHLY_PRICE', '$5'),
    cadence: '/month',
    link: ENV.fetch('STRIPE_MONTHLY_LINK', 'https://buy.stripe.com/6oEeYwea4g6t0jS147')
  },
  annual: {
    price: ENV.fetch('PLAN_ANNUAL_PRICE', '$50'),
    cadence: '/year',
    link: ENV.fetch('STRIPE_ANNUAL_LINK', 'https://buy.stripe.com/00gcQo7LGdYl3w4fZ3'),
    badge: ENV.fetch('PLAN_ANNUAL_BADGE', '2 months free')
  }
}.freeze
