from azureml.core.run import Run
import os
import argparse
from sklearn.datasets import load_diabetes
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split
from sklearn.externals import joblib
import numpy as np


parser = argparse.ArgumentParser("train")
parser.add_argument(
    "--build_id",
    type=str,
    help="The build ID of the build triggering this pipeline run",
)
parser.add_argument(
    "--model_name",
    type=str,
    help="Name of the Model"
)

args = parser.parse_args()

print("Argument 1: %s" % args.build_id)
print("Argument 2: %s" % args.model_name)

model_name = args.model_name
build_id = args.build_id

run = Run.get_context()
exp = run.experiment
ws = run.experiment.workspace

X, y = load_diabetes(return_X_y=True)
columns = ["age", "gender", "bmi", "bp", "s1", "s2", "s3", "s4", "s5", "s6"]
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=0)
data = {"train": {"X": X_train, "y": y_train},
        "test": {"X": X_test, "y": y_test}}

print("Running train.py")

alpha = 0.5
print(alpha)
run.log("alpha", alpha)
run.parent.log("alpha", alpha)
reg = Ridge(alpha=alpha)
reg.fit(data["train"]["X"], data["train"]["y"])
preds = reg.predict(data["test"]["X"])
run.log("mse", mean_squared_error(
    preds, data["test"]["y"]), description="Mean squared error metric")
run.parent.log("mse", mean_squared_error(
    preds, data["test"]["y"]), description="Mean squared error metric")

with open(model_name, "wb") as file:
    joblib.dump(value=reg, filename=model_name)

# upload model file explicitly into artifacts for parent run
run.parent.upload_file(name="./outputs/" + model_name,
                       path_or_stream=model_name)
print("Uploaded the model {} to experiment {}".format(
    model_name, run.experiment.name))
dirpath = os.getcwd()
print(dirpath)
print("Following files are uploaded ")
print(run.parent.get_file_names())

# Add properties to identify this specific training run
run.tag("BuildId", value=build_id)
run.tag("run_type", value="train")
print(f"tags now present for run: {run.tags}")

run.complete()
