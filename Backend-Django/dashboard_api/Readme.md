Give me several test cases for this viewSet. 

Setup includes 1 regular user, with Access to 4 EA and another regular user with access to no a EA's. Two of them are  active, and one of them is expired (the subscribed at, last_paid at dates are one year in the past, and the current time is past the expires_at time, the other one is subscribed by nobody. 

Test, Creating a new Trade, Updating a trade's profit, Trying (and failing) to update a trades lot size, Trying to delete a trade, getting the all the trades (10) for a user. Trying to get the trades for a User that is not yourself. Trying to get the trades of an EA you are not subscribed to, 

I also want a test case for trying checking if a user EA subscription has expired or not 