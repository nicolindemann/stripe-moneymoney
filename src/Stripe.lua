-- Inofficial Stripe Extension (www.stripe.com) for MoneyMoney
-- Fetches balances from Stripe API and returns them as transactions
--
-- Password: Stripe Secret API Key
--
-- Copyright (c) 2018 Nico Lindemann
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking{version     = 1.00,
           url         = "https://api.stripe.com/",
           services    = {"Stripe Account"},
           description = "Fetches balances from Stripe API and returns them as transactions"}

local apiSecret
local account
local apiUrlVersion = "v1"

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Stripe Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  account = username
  apiSecret = password
end

function ListAccounts (knownAccounts)
  local account = {
    name = "Stripe Account",
    accountNumber = account,
    type = AccountTypeGiro
  }

  return {account}
end

function RefreshAccount (account, since)
  return {balances=GetBalances(), transactions=GetTransactions(since)}
end

function StripeRequest (endPoint)
  local headers = {}

  headers["Authorization"] = "Bearer " .. apiSecret
  headers["Accept"] = "application/json"

  connection = Connection()
  content = connection:request("GET", url .. apiUrlVersion .. "/" .. endPoint, nil, nil, headers)
  json = JSON(content)

  return json
end

function GetBalances ()
  local balances = {}

  stripeBalances = StripeRequest("balance"):dictionary()["available"]

  for key, value in pairs(stripeBalances) do
    local balance = {}
    balance[1] = (value["amount"] / 100)
    balance[2] = string.upper(value["currency"])
    balances[#balances+1] = balance
  end

  return balances
end

function GetTransactions (since)
  local transactions = {}
  local lastTransaction = nil
  local moreItemsAvailable
  local requestString

  repeat
    if lastTransaction == nil then
      requestString = "balance_transactions?limit=100&created[gt]=" .. since
    else
      requestString = "balance_transactions?limit=100&created[gt]=" .. since .. "&starting_after=" .. lastTransaction
    end

    stripeObject = StripeRequest(requestString):dictionary()
    moreItemsAvailable = stripeObject["has_more"]

    for key, value in pairs(stripeObject["data"]) do
      lastTransaction = value["id"]
      purpose = value["type"]

      if value["description"] then
        purpose = purpose .. "\n" .. value["description"]
      end
      if value["fee"] == 0 then
        transactions[#transactions+1] = {
          bookingDate = value["created"],
          valueDate = value["available_on"],
          purpose = purpose,
          endToEndReference = value["source"],
          amount = (value["amount"] / 100),
          currency = string.upper(value["currency"])
        }
      else
        for feeKey, feeValue in pairs(value["fee_details"]) do
          transactions[#transactions+1] = {
            bookingDate = value["created"],
            valueDate = value["available_on"],
            purpose = feeValue["type"] .. "\n" .. feeValue["description"],
            amount = (feeValue["amount"] / 100) * -1,
            currency = string.upper(feeValue["currency"])
          }
        end
        transactions[#transactions+1] = {
          bookingDate = value["created"],
          valueDate = value["available_on"],
          purpose = purpose,
          endToEndReference = value["source"],
          amount = (value["amount"] / 100),
          currency = string.upper(value["currency"])
        }
      end
    end

  until(not moreItemsAvailable)

  return transactions
end

function EndSession ()
  -- Logout.
end
