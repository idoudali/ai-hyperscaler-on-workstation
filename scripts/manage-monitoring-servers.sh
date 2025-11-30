#!/bin/bash
# Manage monitoring servers

COMMAND=${1:-status}

case $COMMAND in
    start)
        echo "Starting monitoring servers..."
        SCRIPT_DIR=$(dirname "$(realpath "$0")")
        JOB_DIR="$SCRIPT_DIR/../examples/slurm-jobs/monitoring"

        sbatch "$JOB_DIR/tensorboard-server.sbatch"
        sbatch "$JOB_DIR/aim-server.sbatch"
        sbatch "$JOB_DIR/mlflow-server.sbatch"
        echo "Servers submitted. Check with: squeue -u $USER"
        ;;

    stop)
        echo "Stopping monitoring servers..."
        scancel -u "$USER" -n tensorboard
        scancel -u "$USER" -n aim-server
        scancel -u "$USER" -n mlflow-server
        echo "Servers stopped."
        ;;

    status)
        echo "Monitoring Server Status:"
        squeue -u "$USER" -n tensorboard,aim-server,mlflow-server -o "%.18i %.20j %.8u %.8T %.10M %.10l %.6D %.20R"
        ;;

    view-test)
        TEST_ID=$2
        TOOL=${3:-aim}

        if [ -z "$TEST_ID" ]; then
            echo "Usage: $0 view-test <test_id> [aim|tensorboard]"
            echo "Example: $0 view-test 13-MNIST-job-completes... aim"
            exit 1
        fi

        # Validate TEST_ID format (alphanumeric, hyphens, underscores only)
        if [[ "$TEST_ID" =~ [^a-zA-Z0-9_-] ]]; then
            echo "ERROR: Invalid TEST_ID format. Use alphanumeric, hyphens, or underscores only."
            exit 1
        fi

        SCRIPT_DIR=$(dirname "$(realpath "$0")")
        JOB_DIR="$SCRIPT_DIR/../examples/slurm-jobs/monitoring"
        TEST_ROOT="/mnt/beegfs/tests"
        TEST_DIR="$TEST_ROOT/$TEST_ID"

        if [ ! -d "$TEST_DIR" ]; then
            echo "ERROR: Test directory not found: $TEST_DIR"
            exit 1
        fi

        echo "Starting visualization for test: $TEST_ID"

        case $TOOL in
            aim)
                REPO_PATH="$TEST_DIR/monitoring-logs/aim/.aim"
                if [ ! -d "$REPO_PATH" ]; then
                    # Fallback: try without .aim suffix if it was initialized differently
                    REPO_PATH="$TEST_DIR/monitoring-logs/aim"
                fi

                echo "Aim Repo: $REPO_PATH"
                # Use --export to pass the AIM_REPO variable to the job
                sbatch --export=ALL,AIM_REPO="$REPO_PATH" --job-name="aim-$TEST_ID" "$JOB_DIR/aim-server.sbatch"
                echo "Aim server submitted for test $TEST_ID"
                ;;
            *)
                echo "Tool '$TOOL' not supported for test viewing yet."
                exit 1
                ;;
        esac
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        ;;

    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
