Feature: Secure login to the portal
  As a loan applicant
  I want to log in securely using my credentials
  So that only I can access my application and personal data

  Background:
    Given the loan portal login page is accessible
    And the following registered user exists:
      | email                  | password       | mobile      |
      | john.doe@example.com   | P@ssw0rd!23    | +1234567890 |

  Happy path

  Scenario: Successful login with email and password
    Given I am on the login page
    When I enter email "john.doe@example.com" and password "P@ssw0rd!23"
    And I click "Sign in"
    Then I should be redirected to my application dashboard
    And a valid JWT token should be issued and stored in the session
    And the token expiry should be set to 30 minutes from login time

  Scenario: Successful login with OTP via mobile number
    Given I am on the login page
    When I select "Login with OTP"
    And I enter my registered mobile number "+1234567890"
    And I click "Send OTP"
    Then an OTP should be sent to "+1234567890" within 30 seconds
    When I enter the correct OTP
    Then I should be redirected to my application dashboard
    And a valid JWT token should be issued and stored in the session

OTP expiry 

  Scenario: OTP expires after 5 minutes
    Given I am on the OTP verification page
    And an OTP was sent to my mobile number
    When I wait for more than 5 minutes before entering the OTP
    And I enter the expired OTP
    Then I should see the error "OTP has expired. Please request a new one."
    And I should not be logged in

  Scenario: Resend OTP successfully
    Given I am on the OTP verification page
    And the OTP has expired
    When I click "Resend OTP"
    Then a new OTP should be sent to my registered mobile within 30 seconds
    And the previous OTP should be invalidated

 Failed login 

  Scenario: Login fails with incorrect password
    Given I am on the login page
    When I enter email "john.doe@example.com" and password "WrongPass!99"
    And I click "Sign in"
    Then I should see the error "Invalid email or password."
    And I should remain on the login page
    And no JWT token should be issued

  Scenario Outline: Account is locked after 3 consecutive failed login attempts
    Given I am on the login page
    And I have already failed login <previous_failures> times with wrong credentials
    When I enter email "john.doe@example.com" and password "WrongPass!99"
    And I click "Sign in"
    Then I should see the error "Too many failed attempts. Your account is locked for 15 minutes."
    And the account should be locked for 15 minutes
    And a security alert email should be sent to "john.doe@example.com"

    Examples:
      | previous_failures |
      | 2                 |

  Scenario: Locked account cannot log in during lockout period
    Given my account is locked due to failed login attempts
    When I attempt to log in with correct credentials
    Then I should see "Account locked. Try again after <remaining time>."
    And I should not be redirected to the dashboard

  Scenario: Account is unlocked after 15-minute lockout period
    Given my account was locked 15 minutes ago
    When I attempt to log in with correct credentials
    Then I should be successfully logged in
    And the failed attempt counter should be reset to 0

  Session management

  Scenario: Session expires after 30 minutes of inactivity
    Given I am logged in to the portal
    When I am inactive for more than 30 minutes
    Then my session should expire automatically
    And I should be redirected to the login page
    And I should see the message "Your session has expired. Please log in again."
    And the JWT token should be invalidated server-side

  Scenario: Active session is maintained within the 30-minute window
    Given I am logged in to the portal
    When I perform an action within 25 minutes of my last activity
    Then my session should remain active
    And the 30-minute inactivity timer should reset

  Scenario: Logging out invalidates the session
    Given I am logged in to the portal
    When I click "Log out"
    Then my JWT token should be invalidated server-side
    And I should be redirected to the login page
    And navigating back should not restore my session

  Security edge cases 

  Scenario: Login with unregistered email is rejected
    Given I am on the login page
    When I enter email "unknown@example.com" and password "AnyPass!123"
    And I click "Sign in"
    Then I should see the generic error "Invalid email or password."
    And no account-specific information should be revealed

  Scenario: Login page is served over HTTPS
    When I navigate to the portal login page
    Then the page URL should begin with "https://"
    And the SSL certificate should be valid

  Scenario: Password field input is masked
    Given I am on the login page
    When I type in the password field
    Then the characters should be masked and not visible in plain text

  Scenario: Brute force attempt from multiple IPs is rate-limited
    Given the rate limiter is active
    When more than 10 login attempts are made from the same IP within 1 minute
    Then subsequent requests from that IP should receive HTTP 429 Too Many Requests
    And the response should include a Retry-After header

