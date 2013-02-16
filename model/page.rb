# -*- encoding: utf-8 -*-
require 'nokogiri'
require 'domainatrix'
require 'json'
require 'json/ext'


class Page
  class PageError < StandardError
  end
  SEPARATOR = "%SEP%"
  NO_LIMIT = 0
  # attribut en input
  attr :url, # url de la page
       :id, # id logique d'une page
       :document # le contenu de la page
  # attribut en output
  attr :title, # titre recuper� de la page html
       :body_not_html, # body non html de la page
       :body_html # body html de la page
  attr_reader :links # liens conserv�s de la page
  # attribut private
  attr :parsed_document, # le document pars� avec nokogiri
       :root_url, # url root du site d'o� provient la page
       :schemes # ensemble de schemes recherch�s dans une page


  def initialize(id, url, document)
    begin
      @id = id
      @url = url
      @document = document
      parse()
    rescue Exception => e
      raise PageError, e.message
    end
  end

  def to_json(*a)
    @links = [] if @links.nil?
    {
        'id' => @id,
        'url' => @url,
        'title' => @title,
        'links' => @links,
        'count_word' => count_word()
    }.to_json(*a)
  end


  def to_s(*a)
    @links = [] if @links.nil?

    uri = URI(@url)
    url = "/"
    url = uri.path unless uri.path.nil?
    url += "?#{uri.query}" unless uri.query.nil?
    url += "##{uri.fragment}" unless uri.fragment.nil?

    "#{@id}#{SEPARATOR}#{uri.host}#{SEPARATOR}#{url}#{SEPARATOR}#{@title}#{SEPARATOR}#{@links}#{SEPARATOR}#{count_word()}"
  end

  def title
    begin
      @title ||= @parsed_document.title() #.gsub(/\t|\n|\r/, ''), permet d'enlever ces caracteres
    rescue Exception => e
      @title = ""
    end
  end

# ---------------------------------------------------------------------------------------------------------------------
# links (root_url, schemes, type)
# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
#   root_url : url de d�part
#   schemes : Array de scheme des links � s�lectionner
#       :http, :https, :file, :mailto, ...
#   type : Array des type de liens � s�lectionner
#       :local : liens du document dont leur host est celui du document
#       :global : liens du document dont leur host est un sous-domaine du host du document
#       :full : liens du documents qq soit leur host qui ne sont pas LOCAL, ni GLOBAL
#        pour avoir tous les liens il faut specifier [LOCAL, GLOBAL, FULL]
# ---------------------------------------------------------------------------------------------------------------------
# OUTPUT
# Array d'url absolue
# ---------------------------------------------------------------------------------------------------------------------
  def extract_links(root_url = nil, count_link = NO_LIMIT, schemes = [:http], type = [:local, :global])
    @schemes = schemes
    uri = URI.parse(root_url)
    raise PageError, "scheme (#{uri.scheme}) is not acceptable scheme [:http, :https] : #{uri}" unless [:http, :https].include?(uri.scheme.to_sym)
    @root_url = "#{uri.scheme}://#{uri.host}:#{uri.port}/#{uri.path}/"
    @links = parsed_links.map { |l|
      begin
        abs_l = absolutify_url(unrelativize_url(l))
        # on ne conserve que les link qui r�pondent � la s�lection sur le
        abs_l if acceptable_scheme?(abs_l) and # scheme
            acceptable_link?(type, abs_l, @root_url) # le perim�tre : domaine, sous-domaine, hors du domaine
      rescue Exception => e
      end
    }.compact
    # on retourne un nombre limite si besoin
    @links = @links[0..count_link - 1] if count_link != NO_LIMIT
    @links
  end

  # ces deux fonctions doivent rester en public sinon cela bug
  def acceptable_scheme?(l)
    @schemes.include?(URI.parse(l).scheme.to_sym)  or  @schemes.include?(URI.parse(l).scheme)
  end

  def acceptable_link?(type, l, r)
    # r : le host du site
    # l : le lien que l'on veut analyser
    r_host = URI.parse(r).host
    if r_host != "localhost"
      # on s'assure qu'on est pas sur un domain localhost car dominatrix ne fonctionne pas sans TLD (.fr)
      l = Domainatrix.parse(l)
      r = Domainatrix.parse(r)
      if l.subdomain == r.subdomain and
          l.domain == r.domain and
          l.public_suffix == r.public_suffix
        type.include?(:local) or type.include?("local")
      else
        if l.domain == r.domain and
            l.public_suffix == r.public_suffix
          type.include?(:global) or type.include?("global")
        else
          type.include?(:full)  or type.include?("full")
        end
      end
    else
      if  r_host == URI.parse(l).host
        type.include?(:local) or type.include?("local")
      else
        type.include?(:full)or type.include?("full")
      end
    end
  end

  # ---------------------------------------------------------------------------------------------------------------------
  # body(format = :html)
  # ---------------------------------------------------------------------------------------------------------------------
  # INPUTS
  # format : le type de restitution
  #         :text : sans les mots du langage html
  #         :html : avec les mots du langage html
  # ---------------------------------------------------------------------------------------------------------------------
  # OUTPUTS
  # le contenu de la balise body
  # ---------------------------------------------------------------------------------------------------------------------
  def body(format = :html)
    return @body_not_html ||= @parsed_document.search("//body").inner_text if format == :text
    @body_html ||= @parsed_document.search("//body").inner_html if format == :html
  end

# ---------------------------------------------------------------------------------------------------------------------
  private
# ---------------------------------------------------------------------------------------------------------------------
  def parse()
    begin
      @parsed_document ||= Nokogiri::HTML(@document)
    rescue Exception => e
      raise PageError, "Parsing exception: #{e.message}"
    end
  end


  def parsed_links
    begin
      @parsed_document.search("//a").map { |link|
        link.attributes["href"].to_s.strip
      }.uniq
    rescue Exception => e
      []
    end
  end

  # Convert a relative url like "/users" to an absolute one like "http://example.com/users"
  # Respecting already absolute URLs like the ones starting with http:, ftp:, telnet:, mailto:, javascript: ...
  def absolutify_url(url)
    if url =~ /^\w*\:/i
      url
    else
      URI.parse(@root_url).merge(URI.encode(url)).to_s.gsub("%23", "#")
    end
  end

  # Convert a protocol-relative url to its full form, depending on the scheme of the page that contains it
  def unrelativize_url(url)
    url =~ /^\/\// ? "#{scheme}://#{url[2..-1]}" : url
  end

  def count_word()
    begin
      @body_not_html.scan(Regexp.new(/[[:word:]]+/)).size
    rescue Exception => e
      # mesure d�grad�e, tant pis ....
      @body_not_html.size
    end
  end
end
# End Class Page ------------------------------------------------------------------------------------------------
