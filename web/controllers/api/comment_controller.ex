defmodule Microscope.CommentController do
  use Microscope.Web, :controller

  plug Guardian.Plug.EnsureAuthenticated,
    [handler: Microscope.SessionController] when action in [:create, :delete]

  alias Microscope.{Repo, Post, Comment, PostChannel}

  def index(conn, %{"post_id" => post_id}) do
    comments = %Post{id: post_id}
      |> assoc(:comments)
      |> order_by(asc: :inserted_at)
      |> Repo.all

    conn
    |> put_status(:ok)
    |> render("index.json", comments: comments)
  end

  def create(conn, %{"comment" => comment_params, "post_id" => post_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    post = Repo.get!(Post, post_id)

    changeset = post
      |> build_assoc(:comments)
      |> Comment.changeset(%{comment_params | "author" => current_user.username})

    case Repo.insert(changeset) do
      {:ok, comment} ->
        PostChannel.broadcast_all(current_user.id, post_id)
        conn
        |> put_status(:created)
        |> render("show.json", comment: comment)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "post_id" => post_id, "comment" => comment_params}) do
    current_user = Guardian.Plug.current_resource(conn)

    changeset = Comment
      |> Repo.get_by!(id: id, post_id: post_id, author: current_user.username)
      |> Comment.changeset(comment_params)

    case Repo.update(changeset) do
      {:ok, comment} ->
        PostChannel.broadcast_all(current_user.id, post_id)
        conn
        |> put_status(:ok)
        |> render("show.json", comment: comment)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id, "post_id" => post_id}) do
    current_user =  Guardian.Plug.current_resource(conn)

    Comment
    |> Repo.get_by!(id: id, post_id: post_id, author: current_user.username)
    |> Repo.delete!

    PostChannel.broadcast_all(current_user.id, post_id)

    conn
    |> put_status(:ok)
    |> render("delete.json")
  end
end
