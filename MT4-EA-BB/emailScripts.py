import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# 🚨 For security, do not hardcode credentials in production! Use environment variables instead.
SENDER_EMAIL = "your_email@example.com" # INPUT: SENDER EMAIL 
SENDER_PASSWORD = "" # INPUT: EMAIL APP PASSWORD
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465  # Use 587 for TLS (change if needed)
BACKLINK  = ''

# Function to send an email
def send_email(recipient, subject, body):
    try:
        # Create the email
        msg = MIMEMultipart()
        msg["From"] = SENDER_EMAIL
        msg["To"] = recipient
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "html"))  # Using HTML for formatting

        # Connect to SMTP server
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, context=context) as server:
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            server.sendmail(SENDER_EMAIL, recipient, msg.as_string())

        print(f"✅ Email sent successfully to {recipient}")
    except Exception as e:
        print(f"❌ Failed to send email: {e}")

# Function to send a Welcome Email
def send_welcome_email(user_email):
    subject = "Welcome to Trade Pro FX!"
    body = f"""
    <html>
    <body>
        <h2>Welcome to Trade Pro FX!</h2>
        <p>Dear User,</p>
        <p>Thank you for registering. We are excited to have you with us.</p>
        <p>Best Regards,<br>Trade Pro FX Team</p>
        <p><a href="{BACKLINK}">Unsubscribe</a></p>
    </body>
    </html>
    """
    send_email(user_email, subject, body)

# Function to send Expiration Notification (4 days before expiration)
def send_expiration_warning(user_email, days_remaining=4):
    subject = f"Your EA License is Expiring in {days_remaining} Days!"
    body = f"""
    <html>
    <body>
        <h2>Expiration Notice</h2>
        <p>Dear User,</p>
        <p>Your Expert Advisor (EA) license will expire in <b>{days_remaining} days</b>.</p>
        <p>Please renew your subscription to continue using the service.</p>
        <p><a href="{BACKLINK}">Unsubscribe</a></p>
    </body>
    </html>
    """
    send_email(user_email, subject, body)

# Function to send Expiration Notice (on expiration day)
def send_expiration_notice(user_email, admin_email):
    subject = "EA License Expired - Immediate Action Required"
    body = f"""
    <html>
    <body>
        <h2>Your EA License Has Expired</h2>
        <p>Dear User,</p>
        <p>Your Expert Advisor (EA) license has expired. To renew, please visit our website.</p>
        <p>Best Regards,<br>Trade Pro FX Team</p>
        <p><a href="{BACKLINK}">Unsubscribe</a></p>
    </body>
    </html>
    """
    # Send to user
    send_email(user_email, subject, body)
    # Send to admin
    send_email(admin_email, subject, body)
