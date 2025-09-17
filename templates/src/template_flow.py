from prefect import flow, task

@task
def say_hello():
    print("Hallo aus meinem neuen, automatisch erstellten Flow!")

@flow(log_prints=True)
def main_flow():
    say_hello()

if __name__ == "__main__":
    main_flow()