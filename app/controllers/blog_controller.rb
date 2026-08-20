class BlogController < ApplicationController
  def index
    @posts = BlogPost.published
    @custom_nav = true
  end

  def show
    @post = BlogPost.published.find_by(slug: params[:slug])
    unless @post
      redirect_to '/blog', status: :moved_permanently
      return
    end
    @related_posts = BlogPost.published.where.not(id: @post.id).limit(3)
    @custom_nav = true
  end
end
