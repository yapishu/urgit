import * as React from 'react'
import { ci } from '../api'
import { makeRunnerRecovery } from '../runnerRecoveryComponent.js'

// Settings → Runners → a runner's withheld slots (legacy-recovery UI ruling
// 01): the component built against React, with the same-origin,
// session-authorized ci API. Its behaviour lives in runnerRecoveryComponent.js,
// runnerRecoveryView.js and runnerRecovery.js, which the tests drive.
export default makeRunnerRecovery(React, { ci })
