# M17-D — User Invitation & Account Activation

Invitation records are separate from Users. Manager/Operator invitations use hashed single-use 72-hour tokens. Recipients choose a 10+ character password, activation creates the User and authenticated session, resend revokes the prior token, and production SMTP configuration fails closed. Validation domain #29: User Invitation & Account Activation.
