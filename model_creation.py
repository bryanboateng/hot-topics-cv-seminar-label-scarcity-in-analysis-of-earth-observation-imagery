import time
import csv
import torch
from datetime import datetime
import os
import matplotlib.pylab
import matplotlib.ticker
import IPython.display

device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")


def train_model(data_loader, model, criterion, optimizer):
    model.train()
    total_loss = 0.0
    correct_prediction_count = 0
    for inputs, targets in data_loader:
        inputs = inputs.to(device)
        targets = targets.to(device)

        # Foward pass
        outputs = model(inputs)
        _, predictions = torch.max(outputs, 1)
        loss = criterion(outputs, targets)

        # Back-propagation
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * inputs.size(0)
        correct_prediction_count += torch.sum(predictions == targets.data)
    return (
        total_loss / len(data_loader.dataset),
        (correct_prediction_count / len(data_loader.dataset)).item(),
    )


def test_model(model, data_loader, criterion):
    model.eval()
    with torch.no_grad():
        total_loss = 0.0
        correct_prediction_count = 0
        for inputs, targets in data_loader:
            inputs = inputs.to(device)
            targets = targets.to(device)

            outputs = model(inputs)
            _, predictions = torch.max(outputs, 1)
            loss = criterion(outputs, targets)

            total_loss += loss.item() * inputs.size(0)
            correct_prediction_count += torch.sum(predictions == targets.data)
        return (
            total_loss / len(data_loader.dataset),
            (correct_prediction_count / len(data_loader.dataset)).item(),
        )


def export_model(
    model,
    model_name,
    directory_path,
):
    # Create the directory if it doesn't already exist
    os.makedirs(directory_path, exist_ok=True)
    torch.save(model.state_dict(), os.path.join(directory_path, model_name))


def export_loss_and_accuracy(
    training_losses,
    training_accuracies,
    testing_losses,
    testing_accuracies,
    model_descriptor,
    directory_path,
):
    max_length = max(
        len(training_losses),
        len(training_accuracies),
        len(testing_losses),
        len(testing_accuracies),
    )

    padded_training_losses = training_losses + [None] * (
        max_length - len(training_losses)
    )
    padded_training_accuracies = training_accuracies + [None] * (
        max_length - len(training_accuracies)
    )
    padded_testing_losses = testing_losses + [None] * (max_length - len(testing_losses))
    padded_testing_accuracies = testing_accuracies + [None] * (
        max_length - len(testing_accuracies)
    )

    # Create the directory if it doesn't already exist
    os.makedirs(directory_path, exist_ok=True)
    with open(
        os.path.join(directory_path, f"{model_descriptor}_loss_and_accuracy.csv"),
        mode="w",
        newline="",
    ) as file:
        writer = csv.writer(file)
        writer.writerow(
            [
                "epoch",
                "training_loss",
                "training_accuracies",
                "testing_loss",
                "testing_accuracies",
            ]
        )
        writer.writerows(
            zip(
                list(range(1, max_length + 1)),
                padded_training_losses,
                padded_training_accuracies,
                padded_testing_losses,
                padded_testing_accuracies,
            )
        )


def plot_loss(training_losses, testing_losses, model_descriptor, directory_path):
    # Determine the maximum length of the loss sets
    max_length = max(len(training_losses), len(testing_losses))

    # Generate x-axis values based on the maximum length
    x_values = range(1, max_length + 1)

    # Pad the shorter loss set with NaN values to match the length of the longer set
    training_losses_padded = training_losses + [float("nan")] * (
        max_length - len(training_losses)
    )
    testing_losses_padded = testing_losses + [float("nan")] * (
        max_length - len(testing_losses)
    )

    matplotlib.pylab.clf()
    matplotlib.pylab.plot(x_values, training_losses_padded, label="Training Loss")
    matplotlib.pylab.plot(x_values, testing_losses_padded, label="Testing Loss")
    matplotlib.pylab.xlabel("Epoch")
    matplotlib.pylab.ylabel("Loss")
    matplotlib.pylab.title(f"Loss per Epoch - {model_descriptor}")
    matplotlib.pylab.gca().xaxis.set_major_locator(
        matplotlib.ticker.MaxNLocator(integer=True)
    )
    matplotlib.pylab.legend()
    os.makedirs(directory_path, exist_ok=True)
    matplotlib.pylab.savefig(
        os.path.join(directory_path, f"{model_descriptor}_loss_plot.png")
    )
    IPython.display.display(matplotlib.pylab.gcf())
    IPython.display.clear_output(wait=True)


def format_duration(seconds):
    # Calculate the time components
    components = [
        ("w", seconds // 604800),  # 1 week is 604800 seconds
        ("d", seconds // 86400 % 7),  # 1 day is 86400 seconds
        ("h", seconds // 3600 % 24),  # 1 hour is 3600 seconds
        ("min", seconds // 60 % 60),  # 1 minute is 60 seconds
        ("s", round(seconds % 60, 2)),
    ]

    # Only include non-zero components
    components = [(label, value) for label, value in components if value > 0]

    # Format the string
    return ", ".join(f"{value}{label}" for label, value in components)


def log_duration(
    logger,
    is_training,
    epoch,
    phase_start_time,
    model_creation_start_time,
):
    logger.info(
        "    {} Epoch {} done. Phase Duration: {}, Total Duration: {}".format(
            "Training" if is_training else "Testing",
            epoch,
            format_duration(time.time() - phase_start_time),
            format_duration(time.time() - model_creation_start_time),
        )
    )
