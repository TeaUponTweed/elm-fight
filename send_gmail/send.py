from apiclient import errors
from apiclient.discovery import build
from base64 import urlsafe_b64encode
from email.mime.text import MIMEText
from httplib2 import Http
# from oauth2client import file, client, tools
import fire
import pickle

# https://developers.google.com/gmail/api/guides/sending
def create_message(sender, to, subject, message_text):
    """Create a message for an email.
    Args:
      sender: Email address of the sender.
      to: Email address of the receiver.
      subject: The subject of the email message.
      message_text: The text of the email message.
    Returns:
      An object containing a base64url encoded email object.
    """
    message = MIMEText(message_text)
    message['to'] = to
    message['from'] = sender
    message['subject'] = subject
    encoded_message = urlsafe_b64encode(message.as_bytes())
    return {'raw': encoded_message.decode()}


# https://developers.google.com/gmail/api/guides/sending
def send_message(service, user_id, message):
    """Send an email message.
    Args:
      service: Authorized Gmail API service instance.
      user_id: User's email address. The special value "me"
      can be used to indicate the authenticated user.
      message: Message to be sent.
    Returns:
      Sent Message.
    """
    message = (service.users().messages().send(userId=user_id, body=message)
               .execute())
    print('Message Id: %s' % message['id'])
    return message


def make_service():
    SCOPE = 'https://www.googleapis.com/auth/gmail.compose' # Allows sending only, not reading

    # Initialize the object for the Gmail API
    # https://developers.google.com/gmail/api/quickstart/python
    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)
    # If there are no (valid) credentials available, let the user log in.
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            # Save the credentials for the next run
            with open('token.pickle', 'wb') as token:
                pickle.dump(creds, token)
        else:
            raise ValueError("Credential not valid!")
    service = build('gmail', 'v1', credentials=creds)
    return service


def arbitrary(to, subject, msg):
    raw_msg = create_message("donotreply", to, subject, msg)
    send_message(make_service(), "me", raw_msg)


def turn_notification(to, gameID, color):
    subject = f"It's {color}'s turn on game {gameID}"
    msg = f'Go to masonuvagun.xyz?gameID={gameID}&color={color} to make your move'
    raw_msg = create_message("donotreply", to, subject, msg)
    send_message(make_service(), "me", raw_msg)


if __name__ == '__main__':
    fire.Fire()
