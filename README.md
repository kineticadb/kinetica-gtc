# kinetica-gtc

Example code for the Nvidia 2024 GTC conference to demonstrate 
Kinetica DB's AI SQL assistant.

# Getting started.

The kinetica-sqlassist.sh script will create three containers and link
them together through their configs and can be rerun over and over to
recreate and configure the containers.
Two Jupyter notebooks contain the code for the demonstration which can be
accessed at http address and access token show at the end of the script.


- `kinetica-sqlassist` is the Kinetica SQL AI LLM model.
    - Uses port: SQLASSIST_PORT=8050
- `kinetica-jupyter` is a Jupyter notebook with the sample jupyter/ workbooks mounted.
    - Uses port: JUPYTER_PORT=10000
- `kinetica` is a GPU enabled Kinetica DB.
    - Workbench        : http://127.0.0.1:8000/workbench
    - Kinetica Admin   : http://127.0.0.1:8080/gadmin
    - Reveal           : http://127.0.0.1:8088
    - Database REST    : http://127.0.0.1:9191
