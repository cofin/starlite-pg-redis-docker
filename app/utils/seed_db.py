from app.repositories.user import UserRepository
from app.utils.factories import UserCreateDTOFactory


async def seed_db():
    # create users
    if len(await UserRepository.get_many()) < 10:
        for i in range(10):
            user = UserCreateDTOFactory.build().dict()
            user = UserRepository.create(user)
