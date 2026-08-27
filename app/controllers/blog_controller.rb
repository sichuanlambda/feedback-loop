class BlogController < ApplicationController
  # Near-duplicate slugs from the old blog 301 to their canonical post
  SLUG_ALIASES = {
    'cute-house' => 'cute-houses',
    'cutes-house' => 'cute-houses',
    'two-story-tiny-house' => '2-story-tiny-house',
    'tiny-house-loft-ideas' => 'tiny-home-loft-ideas'
  }.freeze

  def index
    @posts = BlogPost.published
    @custom_nav = true
  end

  def show
    if (target = SLUG_ALIASES[params[:slug]])
      redirect_to "/blog/#{target}", status: :moved_permanently
      return
    end

    @post = BlogPost.published.find_by(slug: params[:slug])
    unless @post
      redirect_to '/blog', status: :moved_permanently
      return
    end
    # Same-topic posts first, newest fill the rest
    @related_posts = BlogPost.published.where.not(id: @post.id)
                             .where(cta_category: @post.cta_category).limit(3).to_a
    if @related_posts.size < 3
      @related_posts += BlogPost.published
                                .where.not(id: [@post.id] + @related_posts.map(&:id))
                                .limit(3 - @related_posts.size).to_a
    end
    @custom_nav = true
  end
end
