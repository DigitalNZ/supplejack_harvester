# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :pipeline_tags, dependent: :destroy
  has_many :pipelines, through: :pipeline_tags

  # A name is a single-line label, so it is squished rather than stripped: '  Prod  ' and
  # 'Prod  Line' both reduce to the same slug as their tidy spelling, and without this a
  # stray space reports 'slug has already been taken' instead of the duplicate name it
  # really is. normalizes applies to query values too, so Tag.find_by(name: ' Prod ')
  # still finds the tag.
  normalizes :name, with: ->(name) { name.squish }

  before_validation :assign_slug

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  # A name that is present but has nothing sluggable in it ('!!!') would parameterize to
  # an empty slug and be unreachable from a filter URL. Blank names are the presence
  # validation's business, so this one sits out of them rather than reporting a second
  # error for the same mistake - and it is a separate call because allow_blank applies to
  # every validator in the call it appears on, which would neuter presence above.
  validates :name, format: { with: /[[:alnum:]]/, message: I18n.t('tag.validations.name_format') },
                   allow_blank: true
  validates :slug, uniqueness: true

  scope :ordered, -> { order(:name) }

  # How many pipelines carry each tag, and how many jobs those pipelines have run,
  # keyed by tag id. One query each, for the counts beside the filter checkboxes.
  def self.pipeline_counts
    joins(:pipelines).group(:id).count
  end

  def self.job_counts
    joins(pipelines: :pipeline_jobs).group(:id).count
  end

  # The tags for the names a form submitted, creating the ones that are new. Lookup is
  # by slug rather than name: the slug is what a name normalises to, so 'Prod', 'prod'
  # and ' prod ' all find the one existing tag instead of failing its uniqueness on
  # create. A name that cannot be saved comes back unpersisted, carrying its errors for
  # the caller to report.
  def self.from_names(names)
    Array(names).map { |name| name.to_s.squish }.compact_blank.uniq { it.parameterize }.map do |name|
      find_by(slug: name.parameterize) || create(name:)
    end
  end

  private

  # The slug is what appears in the filter URLs. It follows the name, so renaming a tag
  # rewrites it and the two never drift apart - a link holding the old slug then matches
  # nothing, the same as if the tag had been deleted. Two names that reduce to the same
  # slug ('Prod' and 'Prod!') are caught by the slug uniqueness validation above.
  def assign_slug
    self.slug = name.to_s.parameterize
  end
end
