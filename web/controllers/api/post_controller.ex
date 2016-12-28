defmodule Microscope.PostController do
  use Microscope.Web, :controller

  @preload [:user, :comments, :votes]

  plug Guardian.Plug.EnsureAuthenticated,
    [handler: Microscope.SessionController] when action in [:create, :update, :delete]

  alias Microscope.{Repo, Post, PostChannel}

  def index(conn, _params) do
    posts = Post.preload
      |> Post.order_asc_by_insertion
      |> Repo.all

    conn
    |> put_status(:ok)
    |> render("index.json", posts: posts)
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Post.preload, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render("error.json")
      post ->
        conn
        |> put_status(:ok)
        |> render("show.json", post: post)
    end
  end

  def create(conn, %{"post" => post_params}) do
    current_user = Guardian.Plug.current_resource(conn)

    changeset = current_user
      |> build_assoc(:posts)
      |> Repo.preload(@preload)
      |> Post.changeset(post_params)

    case Repo.insert(changeset) do
      {:ok, post} ->
        PostChannel.broadcast_all(current_user.id, post.id)
        conn
        |> put_status(:created)
        |> render("show.json", post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    user_id = Guardian.Plug.current_resource(conn).id

    changeset = Post.preload
      |> Repo.get_by!(id: id, user_id: user_id)
      |> Post.changeset(post_params)

    case Repo.update(changeset) do
      {:ok, post} ->
        PostChannel.broadcast_all(user_id, id)
        conn
        |> put_status(:ok)
        |> render("show.json", post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = Guardian.Plug.current_resource(conn).id

    Post
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.delete!

    PostChannel.broadcast_all(user_id, id, :delete)

    conn
    |> put_status(:ok)
    |> render("delete.json")
  end
end
