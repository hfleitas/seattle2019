# We import the requests module which allows us to make the API call
import requests
 
# Replace [app_id] with the App ID and [app_secret] with the App Secret
 app_id = 'fp4o2wDF6FEzfrc1TWBQVA'
 app_secret = 'mBWWL0UKTLCFRaW7bp7n8ltlJE79SvQXirCronnLevqW6IZbeVYDw7FYrhQmMDNSovGS7G62hqK6Y1nnk3iIht3C3EHLp7eDdr2uC6qR4FniDs9I6awrKBZ6BaRgW3Yx'
 data = {'grant_type': 'client_credentials',
         'client_id': app_id,
         'client_secret': app_secret}
 token = requests.post('https://api.yelp.com/oauth2/token', data = data)
 access_token = token.json()['access_token']
 headers = {'Authorization': 'bearer %s' % access_token}
 
# Call Yelp API to pull business data for UPCIC universal-property-and-casualty-insurance-company-fort-lauderdale
 biz_id = 'Universal Property and Casualty Insurance Company'
 url = 'https://api.yelp.com/v3/businesses/%s' % biz_id
 response = requests.get(url = url, headers = headers)
 response_data = response.json()