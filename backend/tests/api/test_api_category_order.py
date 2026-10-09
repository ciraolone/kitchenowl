# Ordine dei reparti (fork di Andrea, feature 005): un reparto nuovo va in fondo, dopo quelli già presenti, e il riordino con "ordering" che l'app manda dal trascinamento lo sposta nella posizione indicata.


def add_category(client, household_id, name):
    response = client.post(
        f"/api/household/{household_id}/category", json={"name": name}
    )
    assert response.status_code == 200
    return response.get_json()


def category_names(client, household_id):
    response = client.get(f"/api/household/{household_id}/category")
    return [category["name"] for category in response.get_json()]


def test_new_category_goes_last(user_client_with_household, household_id):
    client = user_client_with_household
    before = category_names(client, household_id)

    add_category(client, household_id, "Zuppe")
    add_category(client, household_id, "Acqua")

    assert category_names(client, household_id) == before + ["Zuppe", "Acqua"]


def test_category_moved_to_a_position_takes_it(
    user_client_with_household, household_id
):
    client = user_client_with_household
    acqua = add_category(client, household_id, "Acqua")
    names = category_names(client, household_id)

    response = client.post(f"/api/category/{acqua['id']}", json={"ordering": 0})

    assert response.status_code == 200
    assert category_names(client, household_id) == ["Acqua"] + names[:-1]
