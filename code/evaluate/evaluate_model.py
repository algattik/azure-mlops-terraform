import os
import sys
from azureml.core import Run, Workspace, Experiment
import argparse
import traceback

run = Run.get_context()
if (run.id.startswith('OfflineRun')):
    from dotenv import load_dotenv
    sys.path.append(os.path.abspath("./code/util"))  # NOQA: E402
    from model_helper import get_model_by_tag
    # For local development, set values in this section
    load_dotenv()
    workspace_name = os.environ.get("WORKSPACE_NAME")
    experiment_name = os.environ.get("EXPERIMENT_NAME")
    resource_group = os.environ.get("RESOURCE_GROUP")
    subscription_id = os.environ.get("SUBSCRIPTION_ID")
    tenant_id = os.environ.get("TENANT_ID")
    model_name = os.environ.get("MODEL_NAME")
    app_id = os.environ.get('SP_APP_ID')
    app_secret = os.environ.get('SP_APP_SECRET')
    build_id = os.environ.get('BUILD_BUILDID')

    aml_workspace = Workspace.get(
        name=workspace_name,
        subscription_id=subscription_id,
        resource_group=resource_group
    )
    ws = aml_workspace
    exp = Experiment(ws, experiment_name)
else:
    sys.path.append(os.path.abspath("./util"))  # NOQA: E402
    from model_helper import get_model_by_tag
    exp = run.experiment
    ws = run.experiment.workspace
    run_id = 'amlcompute'

parser = argparse.ArgumentParser("evaluate")
parser.add_argument(
    "--build_id",
    type=str,
    help="The Build ID of the build triggering this pipeline run",
)
parser.add_argument(
    "--run_id",
    type=str,
    help="Training run ID",
)
parser.add_argument(
    "--model_name",
    type=str,
    help="Name of the Model"
)

args = parser.parse_args()
if (args.build_id is not None):
    build_id = args.build_id
if (args.run_id is not None):
    run_id = args.run_id
if (run_id == 'amlcompute'):
    run_id = run.parent.id
model_name = args.model_name
metric_eval = "mse"
run.tag("BuildId", value=build_id)

# Paramaterize the matrices on which the models should be compared
# Add golden data set on which all the model performance can be evaluated
try:
    firstRegistration = False
    tag_name = 'experiment_name'

    model = get_model_by_tag(
        model_name, tag_name, exp.name, ws)

    if (model is not None):

        production_model_run_id = model.run_id

        # Get the run history for both production model and
        # newly trained model and compare mse
        production_model_run = Run(exp, run_id=production_model_run_id)
        new_model_run = run.parent
        print("Production model run is", production_model_run)

        production_model_mse = \
            production_model_run.get_metrics().get(metric_eval)
        new_model_mse = new_model_run.get_metrics().get(metric_eval)
        if (production_model_mse is None or new_model_mse is None):
            print("Unable to find", metric_eval, "metrics, "
                  "exiting evaluation")
            run.parent.cancel()
        else:
            print(
                "Current Production model mse: {}, "
                "New trained model mse: {}".format(
                    production_model_mse, new_model_mse
                )
            )

        if (new_model_mse < production_model_mse):
            print("New trained model performs better, "
                  "thus it should be registered")
        else:
            print("New trained model metric is less than or equal to "
                  "production model so skipping model registration.")
            run.parent.cancel()
    else:
        print("This is the first model, "
              "thus it should be registered")

except Exception:
    traceback.print_exc(limit=None, file=None, chain=True)
    print("Something went wrong trying to evaluate. Exiting.")
    raise
