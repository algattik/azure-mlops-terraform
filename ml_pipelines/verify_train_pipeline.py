import os
import sys
import argparse
from azureml.core import Run, Experiment, Workspace


def main():

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
        ws = run.experiment.workspace
        exp = run.experiment

    parser = argparse.ArgumentParser("register")
    parser.add_argument(
        "--build_id",
        type=str,
        help="The Build ID of the build triggering this pipeline run",
    )
    parser.add_argument(
        "--model_name",
        type=str,
        help="Name of the Model"
    )

    args = parser.parse_args()
    if (args.build_id is not None):
        build_id = args.build_id
    model_name = args.model_name

    try:
        tag_name = 'BuildId'
        get_model_by_tag(model_name, tag_name, build_id, exp.workspace)
        print("Model was registered for this build.")
    except Exception as e:
        print(e)
        print("Model was not registered for this run.")
        sys.exit(1)


if __name__ == '__main__':
    main()
