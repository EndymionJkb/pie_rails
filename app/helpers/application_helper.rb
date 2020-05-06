module ApplicationHelper
  # Returns the full title on a per-page basis.
  def full_title(page_title)
    page_title.blank? ? "ReviewRight" : "ReviewRight | #{page_title}"
  end

  def get_network_name(network_id)
    case network_id
    when 1
      'Mainnet'
    when 2
      'Morden'
    when 3
      'Ropsten'
    when 4
      'Rinkeby'
    when 5
      'Goerli'
    when 42
      'Kovan'
    else
      'Unknown - private?'
    end
  end
end
