import * as React from 'react'
import { makePullLabels } from '../pullLabelsComponent.js'

// A pull request's labels and, for its owner and writers, their editor
// (%urgit state-5). The behaviour lives in pullLabelsComponent.js and
// pullLabels.js, which the tests drive.
export default makePullLabels(React)
