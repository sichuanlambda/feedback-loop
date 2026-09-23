# Blog content playbook

The blog brings in roughly 60% of the site's search visits, and the posts that
rank are style comparisons and "how to identify" explainers. This is the recipe
for writing more of them and getting them live.

## What to write

Pick topics from the backlog below (or add to it). Every post should be one of:

- **A vs. B** — two styles people confuse (`art-deco-vs-art-nouveau-…`).
- **How to identify X** — one style, spotting guide first (`what-style-is-my-house-…`).
- **X styles compared** — a family of related styles (`victorian-house-styles-…`).

Before writing, `ls db/blog_content | grep -i <topic>` to avoid duplicating an
existing post, and confirm every internal link target returns 200:

- Style pages: `/building_library/styles/<slug>` (kebab-case, e.g. `tudor-revival`).
- Style-in-city pages: `/styles/<style>/in/<city>` — list the live ones with
  `curl -s https://architecturehelper.com/sitemap1.xml.gz | gunzip | grep -o '/styles/[^<]*'`.
- City guides: `/places/<city>`.
- Other posts: `/blog/<slug>`.

## Format (follow the existing posts exactly)

One JSON file per post at `db/blog_content/<slug>.json`:

```json
{
  "slug": "kebab-case-slug-with-the-search-phrase",
  "title": "Style A vs. Style B: How to Tell Them Apart",
  "description": "150–160 characters, states the one-line answer.",
  "hero_image": "",
  "published_at": "YYYY-MM-DDT12:00:00+00:00",
  "body_html": "…"
}
```

`body_html` is plain HTML (no `<h1>`, the template adds it), 850–1,000 words:

1. **Opening paragraph gives the answer.** The single fastest way to tell the
   styles apart, in the first two sentences. No throat-clearing.
2. `<h2>` "The Two at a Glance" — a `<table>` with a `<thead>` row of
   Feature / A / B and 6–9 rows: dates, origin, signature detail, materials,
   symmetry, typical buildings, named examples.
3. One `<h2>` per style — history in two paragraphs with named buildings and
   dates, then "what to look for" concretely. Link to the style's library page
   and 2–4 style-in-city pages inside the prose.
4. `<h2>` "Where the Confusion Comes From" — a `<ul>` of 3–5 reasons.
5. `<h2>` "A Three-Question Test" — a numbered `<ol>`, then one sentence
   linking to `/architecture_explorer/new?src=blog_inline`.
6. `<h2>` "Frequently Asked Questions" — three `<h3>` questions people actually
   search, each answered in 1–2 sentences.

The template inserts a CTA card before the second `<h2>` and another at the end,
so don't add your own CTA boxes. Use HTML entities for accents (`&eacute;`).

Facts must be conservative and checkable: named buildings, architects, and
dates that appear in any standard survey. If unsure of a date, give a decade.
Never invent a building. Don't quote sources or add citations; this is a guide,
not a paper.

## Publishing

1. Locally, from the repo root with rbenv Ruby 3.3 on PATH:
   `bin/rails blog:import blog:classify_ctas` and check the post at
   `http://localhost:3000/blog/<slug>` (or run `bin/rails test test/integration`).
2. Commit the JSON files, push `main`, deploy: `git push heroku main`.
3. Load them in production:
   `heroku run "rake blog:import blog:classify_ctas" -a boiling-atoll-02251`
4. Refresh the sitemap (served from git, so it must be regenerated against
   production and committed): `bin/refresh_sitemap`, then commit
   `public/sitemap*.xml.gz`, push, deploy again.
5. Tell Bing/Yandex/Naver/Seznam about the new posts (Google has no equivalent;
   it picks them up from the sitemap, or request indexing by hand in Search
   Console): `heroku run "rake seo:indexnow DAYS=7" -a boiling-atoll-02251`.
6. Hero images (about $0.07 each in OpenAI credit, needs `GPT_API_KEY_PRODUCTION`):
   `heroku run "rake blog:generate_heroes" -a boiling-atoll-02251` fills every
   post that lacks one, as a ~250 KB JPEG. `SLUGS=a,b` regenerates specific
   posts; `STYLE="…"` appends to the prompt. The prompt comes from
   `HeroImage.prompt` (uses the description, spells out comparison posts, and
   forbids people); look at the result for any post about a named person or
   a specific building before trusting it. For a long run use
   `heroku run:detached` and follow `heroku logs --dyno run.NNNN`.

Blog posts carry TinyAdz slots after each CTA (`app/views/blog/show.html.erb`);
product pages never do.

## Topic backlog

Comparisons (highest yield):
- Mid-Century Modern vs. Contemporary
- Colonial vs. Colonial Revival
- Georgian vs. Federal
- Spanish Colonial Revival vs. Mediterranean Revival
- Tudor vs. Tudor Revival
- Neoclassical vs. Greek Revival
- Beaux-Arts vs. Neoclassical
- Postmodernism vs. Deconstructivism
- Byzantine vs. Romanesque
- Renaissance vs. Baroque
- Arts and Crafts vs. Art Nouveau
- Italianate vs. Renaissance Revival
- Cape Cod vs. Colonial
- Ranch vs. Split-Level
- Bungalow vs. Cottage

Identify / explain:
- How to identify a Tudor Revival house
- How to identify a Colonial Revival house
- How to identify a Mid-Century Modern house
- How to identify a Spanish Colonial Revival house
- How to identify an Art Deco building
- What is a mansard roof (and which styles use it)
- What is half-timbering
- What is a flying buttress
- What is a cornice / entablature / pediment (one post each or combined)
- Skyscraper styles: Chicago School vs. Art Deco vs. International Style

Published in this series so far: Doric/Ionic/Corinthian, Art Deco vs. Art
Nouveau, Gothic vs. Gothic Revival, Victorian house styles, What style is my
house, Craftsman vs. Prairie, Brutalism vs. Modernism, Baroque vs. Rococo,
Romanesque vs. Gothic.
