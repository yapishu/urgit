import * as React from 'react'
import { ci } from '../api'
import { makeCiRecovery } from '../ciRecoveryComponent.js'

// Settings → CI recovery (CI-RECOVERY-1): the component built against
// React, with the same-origin, session-authorized ci API. Its behaviour
// lives in ciRecoveryComponent.js, ciRecoveryView.js and ciRecovery.js,
// which the tests drive.
export default makeCiRecovery(React, { ci })
