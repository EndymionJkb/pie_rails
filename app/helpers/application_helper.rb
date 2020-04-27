module ApplicationHelper
  # Returns the full title on a per-page basis.
  def full_title(page_title)
    page_title.blank? ? "ReviewRight" : "ReviewRight | #{page_title}"
  end
end
