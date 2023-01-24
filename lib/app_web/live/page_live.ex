defmodule AppWeb.PageLive do
  @moduledoc """
  Page LiveView
  """

  use AppWeb, :live_view

  def mount(_params, _session, socket) do
    path = Path.join(:code.priv_dir(:app), "video.mp4")

    {:ok,
     socket
     |> assign(running?: false)
     |> assign(image: nil)
     |> assign(prediction: nil)
     |> assign(serving: serving())
     |> assign(video: Evision.VideoCapture.videoCapture(path))}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <div class="flex-1 flex flex-col justify-center mx-auto max-w-7xl">
        <div class="flex flex-col items-center justify-center">
          <button :if={!@running?} phx-click="start">
            <Heroicons.play solid class="w-32 h-32 fill-gray-300" />
          </button>
        </div>

        <div :if={@running?} class="flex flex-col gap-4">
          <img :if={@image} src={["data:image/jpg;base64,", @image]} class="max-w-3xl" />

          <p :if={@prediction} class="text-2xl">
            <%= @prediction %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("start", _params, socket) do
    send(self(), :run)

    {:noreply, assign(socket, running?: true)}
  end

  def handle_info(:run, %{assigns: %{running?: true}} = socket) do
    frame = socket.assigns.video |> Evision.VideoCapture.read()
    prediction = predict(socket.assigns.serving, frame)

    send(self(), :run)

    {:noreply,
     socket
     |> assign(prediction: prediction)
     |> assign(image: Evision.imencode(".jpg", frame) |> Base.encode64())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  ###########
  # Private #
  ###########

  defp predict(serving, frame) do
    tensor = frame |> Evision.Mat.to_nx() |> Nx.backend_transfer()

    %{predictions: [%{label: label}]} = Nx.Serving.run(serving, tensor)

    label
  end

  defp serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, "microsoft/resnet-50"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "microsoft/resnet-50"})

    Bumblebee.Vision.image_classification(model_info, featurizer,
      top_k: 1,
      compile: [batch_size: 1],
      defn_options: [compiler: EXLA]
    )
  end
end
