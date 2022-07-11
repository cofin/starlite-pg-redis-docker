import logging
from uuid import UUID

from starlite import Controller, Parameter, Provide, Router, delete, get, post, put

from app.config import Paths
from app.models import UserCreateModel, UserModel
from app.repositories import UserRepository

from .utils import CheckPayloadMismatch, filter_for_updated, limit_offset_pagination

logger = logging.getLogger(__name__)

router_dependencies = {"repository": Provide(UserRepository)}


class UsersController(Controller):
    path = ""
    tags = ["Users"]

    @post(
        description="Create a new User by supplying a username and password",
    )
    async def create_user(
        self, data: UserCreateModel, repository: UserRepository
    ) -> UserModel:
        """
        Create a new User by supplying a username and password
        """
        created_user = await repository.create(data=data)
        logger.info("New User: %s", created_user)
        return created_user

    @get(
        dependencies={
            "limit_offset": Provide(limit_offset_pagination),
            "updated_filter": Provide(filter_for_updated),
        },
        description="A paginated list of all Users",
    )
    async def list_users(
        self,
        repository: UserRepository,
        is_active: bool = Parameter(query="is-active", default=True),
    ) -> list[UserModel]:
        """
        Paginated list of all Users
        """
        return await repository.get_many(is_active=is_active)


class UserDetailController(Controller):
    path = "{user_id:uuid}"
    tags = ["Users"]

    @get(cache=True, description="Details of a distinct User")
    async def get_user(self, user_id: UUID, repository: UserRepository) -> UserModel:
        """
        User member view.
        """
        return await repository.get_one(instance_id=user_id)

    @put(
        guards=[CheckPayloadMismatch("id", "user_id").__call__],
        description="Modify a distinct User",
    )
    async def update_user(
        self, user_id: UUID, data: UserModel, repository: UserRepository
    ) -> UserModel:
        """
        Update User member.
        """
        return await repository.partial_update(instance_id=user_id, data=data)

    @delete(
        status_code=200,
        description="Delete the user and return its representation",
    )
    async def delete_user(self, user_id: UUID, repository: UserRepository) -> UserModel:
        """
        Delete User member.
        """
        return await repository.delete(instance_id=user_id)


user_router = Router(
    path=Paths.USERS,
    route_handlers=[UsersController, UserDetailController],
    dependencies=router_dependencies,
)
