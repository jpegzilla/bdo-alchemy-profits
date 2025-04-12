# frozen_string_literal: true

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
    'magic crystal': "searches 'magic crystal'",
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
end

# constants that will be used in by search / scraping scripts
class ENVData
  COOKIE =
    '__RequestVerificationToken=0q_pyZ8OMkALLxxv_pj6ty10hXKTDq3Sl_1NAbV5WYhUAbNvcurT6GwSUDmBRnaZVyEmd0lcTlR3I6X7_cXkAwH-nGQG_G2E6MQZPNcfNd41' # rubocop:disable Layout/LineLength
  RVT = '__RequestVerificationToken=MGf54RSTVQkYrPo4Dvaf9IOuSilYwQIzWfdBI4PhFrV1l1o_e0BRmf78J6I7pVn_gcqj5DAv-G3MfFiWoUqFE3R62-Kxdcm4CgkRGd7oq7Y1'
  WORLD_MARKET_LIST = '/GetWorldMarketList'
  MARKET_SUB_LIST = '/GetWorldMarketSubList'
  MARKET_SEARCH_LIST = '/GetWorldMarketSearchList'
  MARKET_SELL_BUY_INFO = '/GetItemSellBuyInfo'
  MARKET_HOT_LIST = '/GetWorldMarketHotList'
  MARKET_WAIT_LIST = '/GetWorldMarketWaitList'
  REQUEST_OPTS = {
    method: 'post',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
      Cookie: COOKIE
    }
  }.freeze

  def self.get_root_url(region)
    "https://#{CLIConstants::REGION_DOMAINS[region.to_sym]}/Home"
  end
end
