from app import app
from app.models import History

import time
from datetime import datetime
from dbscan1d.core import DBSCAN1D
import numpy as np


# Ogni spesa riconosciuta è (momento della prima spunta, id degli articoli in ordine di spunta): il momento serve a mettere le spese in fila con i ricordi dei trascinamenti (service/item_route.py, fork di Andrea feature 004)
def clusterShoppings(shoppinglist_id: int) -> list[tuple[datetime, list[int]]] | None:
    dropped = History.find_dropped_by_shoppinglist_id(shoppinglist_id)

    if len(dropped) == 0:
        app.logger.info("no history to investigate")
        return None

    # determine shopping instances via clustering
    times = [int(time.mktime(d.created_at.timetuple())) for d in dropped]

    timestamps = np.array(times)
    # time distance for items to be considered in one shopping action (in seconds)
    # 2 ore invece dei 10 minuti originali: Andrea spunta con calma (fork, feature 004)
    eps = 7200
    # minimum size for clusters to be accepted
    min_samples = 5
    dbs = DBSCAN1D(eps=eps, min_samples=min_samples)
    labels = dbs.fit_predict(timestamps)

    if labels is None or len(labels) == 0:
        app.logger.info("no shopping instances identified")
        return None

    # extract indices of clusters into lists
    cluster_count = max(labels) + 1
    clusters = [[] for i in range(cluster_count)]
    for i in range(len(labels)):
        label = labels[i]
        if labels[i] > -1:
            clusters[label].append(i)

    # indices to list of itemlists for each found shopping instance
    shopping_instances = [
        (dropped[cluster[0]].created_at, [dropped[i].item_id for i in cluster])
        for cluster in clusters
        if cluster
    ]

    # remove duplicates in the instances, keeping the order items were checked off:
    # the ordering job learns from that sequence, so a set() here (unordered) would
    # make it learn the item creation order instead
    shopping_instances = [
        (started_at, list(dict.fromkeys(instance)))
        for started_at, instance in shopping_instances
    ]

    return shopping_instances
