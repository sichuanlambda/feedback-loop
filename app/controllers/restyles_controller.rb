require 'aws-sdk-s3'

# "Restyle My Space": upload a photo of your home or a room and re-render it
# in one of the app's canonical architecture styles (image-to-image edit).
class RestylesController < ApplicationController
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_UPLOAD_BYTES = 15.megabytes
  SPACE_TYPES = %w[exterior interior].freeze

  def new
    @styles = StyleNormalizer.all_canonical_styles
    requested = params[:style].presence && StyleNormalizer.normalize(params[:style])
    @preselected_style = StyleNormalizer.known?(requested.to_s) ? requested : nil
    @preselected_space = SPACE_TYPES.include?(params[:space]) ? params[:space] : 'exterior'
    @guest_trial_available = !user_signed_in? && !restyle_guest_trial_used?
    track_event('restyle_view', { style: @preselected_style }.compact)
  end

  def create
    # Guests get exactly one trial restyle (session + hashed-IP capped),
    # mirroring the guest analysis trial.
    if !user_signed_in? && restyle_guest_trial_used?
      redirect_to new_user_registration_path,
                  alert: "You've used your free restyle — create a free account to do another."
      return
    end

    style = StyleNormalizer.normalize(params[:style_name].to_s)
    unless StyleNormalizer.known?(style)
      redirect_to restyle_path, alert: 'Please choose an architecture style from the list.' and return
    end
    space = SPACE_TYPES.include?(params[:space_type]) ? params[:space_type] : 'exterior'

    # Source photo: a fresh upload, or reuse of a prior restyle's photo
    # ("try another style" on the results page — signed-in owners only).
    source_url = nil
    if params[:rerun_from].present? && user_signed_in?
      prior = ArchImageGen.restyles.where(user_id: current_user.id).find_by(id: params[:rerun_from])
      source_url = prior&.source_image_url
    end

    if source_url.blank?
      upload = params[:image]
      if upload.blank?
        redirect_to restyle_path(style: style), alert: 'Please add a photo of your home or room.' and return
      end
      unless valid_upload?(upload)
        redirect_to restyle_path(style: style), alert: 'Please upload a JPG, PNG, or WebP image under 15 MB.' and return
      end
      source_url = upload_source_to_s3(upload)
      if source_url.blank?
        redirect_to restyle_path(style: style), alert: "Sorry, we couldn't save your photo. Please try again." and return
      end
    end

    if user_signed_in?
      # Server-side paywall, same rules as AI generation: subscribers unlimited,
      # free users spend a credit. Spend only after validation/upload succeed.
      unless spend_generation_credit
        track_event('paywall_view', { src: 'restyle_out_of_credits' })
        redirect_to '/pricing?src=restyle_out_of_credits',
                    alert: "You're out of free credits — upgrade to Pro for unlimited restyles." and return
      end
      unless current_user.subscription_status == 'active'
        remaining = current_user.reload.credits
        track_event('restyle_credit_spent', { remaining: remaining })
        flash[:notice] = "Restyling your space! Free credits left: #{remaining}."
      end
    end

    record = ArchImageGen.create!(
      status: 'pending',
      kind: 'restyle',
      user_id: current_user&.id,
      style_name: style,
      space_type: space,
      source_image_url: source_url,
      prompt: restyle_prompt(style, space)
    )
    RestyleImageJob.perform_later(record.id)

    unless user_signed_in?
      # Marks the trial as used (the UserEvent row carries the hashed IP) and
      # lets signup claim this record via claim_guest_restyle_for.
      session[:guest_restyle_id] = record.id
      track_event('restyle_guest_started', { arch_image_gen_id: record.id })
    end

    track_event('restyle_submit', { style: style, space: space, rerun: params[:rerun_from].present?, guest: !user_signed_in? })
    redirect_to restyle_result_path(record)
  end

  def show
    @arch_image = ArchImageGen.restyles.find_by(id: params[:id])
    unless @arch_image
      redirect_to restyle_path, alert: "We couldn't find that restyle." and return
    end
    @styles = StyleNormalizer.all_canonical_styles
  end

  private

  # One free restyle per anonymous visitor, tracked by session and hashed IP
  # (same pattern as the guest analysis trial).
  def restyle_guest_trial_used?
    return true if session[:guest_restyle_id].present?

    ip_hash = request.remote_ip.presence && Digest::SHA256.hexdigest(request.remote_ip)
    return false if ip_hash.blank?

    UserEvent.where(event_type: 'restyle_guest_started', ip_hash: ip_hash)
             .where('created_at > ?', 30.days.ago)
             .exists?
  end

  def valid_upload?(upload)
    upload.respond_to?(:content_type) &&
      ALLOWED_CONTENT_TYPES.include?(upload.content_type) &&
      upload.size.to_i.positive? &&
      upload.size <= MAX_UPLOAD_BYTES
  end

  def upload_source_to_s3(upload)
    ext = { 'image/jpeg' => '.jpg', 'image/png' => '.png', 'image/webp' => '.webp' }[upload.content_type]
    key = "uploads/restyle/#{SecureRandom.uuid}#{ext}"
    s3 = Aws::S3::Resource.new(region: 'us-east-2')
    obj = s3.bucket('architecture-explorer').object(key)
    obj.upload_file(upload.tempfile.path, content_type: upload.content_type) ? obj.public_url : nil
  rescue StandardError => e
    Rails.logger.error "[RestylesController] S3 upload failed: #{e.message}"
    nil
  end

  # The edit prompt: keep the photo recognizably the user's own space while
  # authentically re-rendering it in the chosen canonical style.
  def restyle_prompt(style, space)
    if space == 'interior'
      "Redesign the room in this photo in the authentic #{style} style. " \
      "Keep the same camera angle, room layout, wall and window positions, and overall proportions " \
      "so it is recognizably the same room, but transform the furnishings, materials, finishes, " \
      "colors, lighting fixtures, and decor to genuinely reflect #{style} design. " \
      "Photorealistic interior photograph, no text or watermarks."
    else
      "Redesign the building in this photo in the authentic #{style} architectural style. " \
      "Keep the same camera angle, framing, building size and massing, and window and door positions " \
      "so it is recognizably the same home, but transform the facade materials, roofline, trim, " \
      "colors, and architectural details to genuinely reflect #{style} architecture. " \
      "Photorealistic exterior photograph, no text or watermarks."
    end
  end
end
