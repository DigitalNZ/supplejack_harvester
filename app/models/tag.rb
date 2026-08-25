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

  validates :name, presence: true, uniqueness: true, length: { in: 2..50, allow_blank: true }
  validates :slug, uniqueness: true
  validate :name_reduces_to_a_slug

  scope :ordered, -> { order(:name) }

  # The colours a tag can be shown in, in the order the picker offers them. The names are
  # the palette's own convention - what https://color-name-generator.com/ calls each hex -
  # and the hexes themselves live with the modifiers they belong to, in
  # stylesheets/blocks/_tag.scss. Pompeii Ash is the grey a tag starts as.
  #
  # validate: true rather than the default: a colour the picker could not have offered
  # arrives as an ordinary validation failure instead of an ArgumentError nothing catches.
  enum :color, {
    pompeii_ash: 0,
    roxy_brown: 1,
    unmatched_beauty: 2,
    tennis_court: 3,
    alligator: 4,
    camouflage_green: 5,
    cloudy_camouflage: 6,
    boating_green: 7,
    dead_blue_eyes: 8,
    purple_rain: 9,
    ultra_violet_lentz: 10,
    secret_affair: 11
  }, default: :pompeii_ash, validate: true

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

  # A name has to reduce to something: '!!' is present and long enough, but parameterizes
  # to nothing, and no filter URL could name it. This is the rule the old format
  # validation was standing in for, and asking what the slug came out as says it directly
  # - as well as leaving Brakeman nothing to object to, which an unanchored regex in a
  # validation always will. Blank names are the presence validation's business.
  def name_reduces_to_a_slug
    return if name.blank? || slug.present?

    errors.add(:name, I18n.t('tag.validations.name_format'))
  end

  # The slug is what appears in the filter URLs. It follows the name, so renaming a tag
  # rewrites it and the two never drift apart - a link holding the old slug then matches
  # nothing, the same as if the tag had been deleted. Two names that reduce to the same
  # slug ('Prod' and 'Prod!') are caught by the slug uniqueness validation above.
  def assign_slug
    self.slug = name.to_s.parameterize
  end
end
