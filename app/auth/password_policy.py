MIN_PASSWORD_LENGTH=10
def validate_password(password:str)->None:
    if not password or len(password)<MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters")
