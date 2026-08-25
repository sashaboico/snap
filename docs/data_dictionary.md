# Data Dictionary

To be filled in once `01_load_data.R` confirms actual column names in the
CSV export. Expected fields based on the dataset's BSON schema:

| Field           | Description                                      |
|-----------------|---------------------------------------------------|
| sender           | Sender's Venmo user ID / username (pseudonymous)  |
| recipient         | Recipient's Venmo user ID / username (pseudonymous) |
| timestamp        | Time of transaction                               |
| memo / note       | Text description of the transaction               |
| emoji            | Emoji included in the transaction note (if any)    |
| audience setting  | public / friends / private                         |
| likes / comments  | Engagement on the public post                      |

Note: dollar amounts are NOT included in this dataset.
