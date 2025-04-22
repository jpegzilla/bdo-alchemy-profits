# frozen_string_literal: true

require 'date'

$request_verification_token = '__RequestVerificationToken=0q_pyZ8OMkALLxxv_pj6ty10hXKTDq3Sl_1NAbV5WYhUAbNvcurT6GwSUDmBRnaZVyEmd0lcTlR3I6X7_cXkAwH-nGQG_G2E6MQZPNcfNd41' # rubocop:disable Layout/LineLength

module Utils
  # constants to use when user is configuring the tool
  class CLIConstants
    CATEGORY_OPTIONS = {
      all: 'collates everything',
      offensive: 'category 35, subcategory 1',
      defensive: 'category 35, subcategory 2',
      functional: 'category 35, subcategory 3',
      potion: 'category 35, subcategory 5',
      other: 'category 35, subcategory 8',
      blood: 'searches "\'s blood"',
      oil: "searches 'oil of'",
      'alchemy stone': "searches 'stone of'",
      reagent: "searches 'reagent'",
      'black stone': 'category 30, subcategory 1',
      'misc': 'category 25, subcategory 8',
      'other tools': 'category 40, subcategory 10',
      # 'magic crystal': "searches 'magic crystal'",
      exit: 'stops the search'
    }.freeze

    REGION_DOMAINS = {
      na: 'na-trade.naeu.playblackdesert.com',
      eu: 'eu-trade.naeu.playblackdesert.com',
      eu_console: 'eu-trade.console.playblackdesert.com',
      na_console: 'na-trade.console.playblackdesert.com',
      asia_console: 'asia-trade.console.playblackdesert.com',
      sea: 'trade.sea.playblackdesert.com',
      mena: 'trade.tr.playblackdesert.com',
      kr: 'trade.kr.playblackdesert.com',
      ru: 'trade.ru.playblackdesert.com',
      jp: 'trade.jp.playblackdesert.com',
      th: 'trade.th.playblackdesert.com',
      tw: 'trade.tw.playblackdesert.com',
      sa: 'blackdesert-tradeweb.playredfox.com',
      exit: 'stops the search'
    }.freeze

    REGION_LANGUAGES = {
      us: 'us english',
      de: 'deutsch',
      fr: 'français',
      ru: 'русский',
      es: 'español (na/eu)',
      sp: 'español (sa)',
      pt: 'português',
      jp: '日本語',
      kr: '한국어',
      cn: '中文',
      tw: '繁体中文',
      th: 'ภาษาไทย',
      tr: 'türkçe',
      id: 'basa indonesia',
      se: 'sea english',
      gl: 'global lab',
      exit: 'stops the search'
    }.freeze

    AGGRESSION_LEVELS = {
      normal: 'evaluate one permutation of each recipe',
      hyperaggressive: 'evaluate every substitution for every recipe',
      exit: 'stops the search'
    }.freeze

    def self.set_rvt(rvt)
      $request_verification_token = rvt
    end
  end

  # constants that will be used in by search / scraping scripts
  class ENVData
    MARKET_CACHE = './market_cache'
    BDO_CODEX_CACHE = './bdo_codex_cache'
    ERROR_LOG = './error.log'
    COOKIE = $request_verification_token
    RVT = $request_verification_token
    WORLD_MARKET_LIST = '/GetWorldMarketList'
    MARKET_SUB_LIST = '/GetWorldMarketSubList'
    MARKET_SEARCH_LIST = '/GetWorldMarketSearchList'
    MARKET_SELL_BUY_INFO = '/GetItemSellBuyInfo'
    MARKET_HOT_LIST = '/GetWorldMarketHotList'
    MARKET_WAIT_LIST = '/GetWorldMarketWaitList'
    REQUEST_OPTS = {
      method: 'post',
      central_market_headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        Cookie: COOKIE,
        Dnt: '1',
      },
      bdo_codex_headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        Dnt: '1'
      }
    }.freeze

    def self.get_central_market_headers(incap_cookie = '')
      original_cookie = REQUEST_OPTS[:central_market_headers][:Cookie]
      if rand > 0.5
        REQUEST_OPTS[:central_market_headers]
        { **REQUEST_OPTS[:central_market_headers], 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36', Cookie: "#{original_cookie};#{incap_cookie}" }
      else
        { **REQUEST_OPTS[:central_market_headers], 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36', Cookie: "#{original_cookie};#{incap_cookie}" }
      end
    end

    def self.get_incap_cookie(region_domain)
      new_expiry = Date.today + 365
      day = Time.now.strftime("%a")
      month = Time.now.strftime("%b")
      hour = rand(1..12)
      minute = rand(1..60)
      second = rand(1..60)

      # TODO: EXPERIMENTAL - figure out how to simulate incapsula data
      "visid_incap_2504212=xoYUIj+XR/acq/q6uc0RZyLI/2cAAAAAQUIPAAAAAAAMYr/xXVQYe6Eo4uVK+L6V; expires=#{day}, #{new_expiry.day} #{month} #{new_expiry.year} #{hour}:#{minute}:#{second} GMT; HttpOnly; path=/; Domain=.#{region_domain}; Secure; SameSite=None"
    end

    def self.get_root_url(region)
      "https://#{CLIConstants::REGION_DOMAINS[region.to_sym]}/Home"
    end
  end
end
