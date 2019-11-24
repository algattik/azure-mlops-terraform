import os
import sys
import argparse
import traceback
from azureml.core import Run, Experiment, Workspace
from azureml.core.model import Model as AMLModel


def main():

    run = Run.get_context()
    if (run.id.startswith('OfflineRun')):
        from dotenv import load_dotenv
        # For local development, set values in this section
        load_dotenv()
        workspace_name = os.environ.get("WORKSPACE_NAME")
        experiment_name = os.environ.get("EXPERIMENT_NAME")
        resource_group = os.environ.get("RESOURCE_GROUP")
        subscription_id = os.environ.get("SUBSCRIPTION_ID")
        build_id = os.environ.get('BUILD_BUILDID')
        aml_workspace = Workspace.get(
            name=workspace_name,
            subscription_id=subscription_id,
            resource_group=resource_group
        )
        ws = aml_workspace
        exp = Experiment(ws, experiment_name)
    else:
        ws = run.experiment.workspace
        exp = run.experiment
        run_id = 'amlcompute'

    parser = argparse.ArgumentParser("register")
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

    if (build_id is None):
        register_aml_model(model_name, exp, run_id)
    else:
        run.tag("BuildId", value=build_id)
        register_aml_model(model_name, exp, run_id, build_id)


def model_already_registered(model_name, exp, run_id):
    model_list = AMLModel.list(exp.workspace, name=model_name, run_id=run_id)
    if len(model_list) >= 1:
        e = ("Model name:", model_name, "in workspace",
             exp.workspace, "with run_id ", run_id, "is already registered.")
        print(e)
        raise Exception(e)
    else:
        print("Model is not registered for this run.")


def register_aml_model(model_name, exp, run_id, build_id: str = 'none'):
    try:
        if (build_id != 'none'):
            model_already_registered(model_name, exp, run_id)
            run = Run(experiment=exp, run_id=run_id)
            tagsValue = {"area": "diabetes", "type": "regression",
                         "BuildId": build_id, "run_id": run_id,
                         "experiment_name": exp.name}
        else:
            run = Run(experiment=exp, run_id=run_id)
            if (run is not None):
                tagsValue = {"area": "diabetes", "type": "regression",
                             "run_id": run_id, "experiment_name": exp.name}
            else:
                print("A model run for experiment", exp.name,
                      "matching properties run_id =", run_id,
                      "was not found. Skipping model registration.")
                sys.exit(0)

        model = run.register_model(model_name=model_name,
                                   model_path="./outputs/" + model_name,
                                   tags=tagsValue)
        os.chdir("..")
        print(
            "Model registered: {} \nModel Description: {} "
            "\nModel Version: {}".format(
                model.name, model.description, model.version
            )
        )
    except Exception:
        traceback.print_exc(limit=None, file=None, chain=True)
        print("Model registration failed")
        raise


if __name__ == '__main__':
    main()
